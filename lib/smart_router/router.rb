# frozen_string_literal: true

require_relative 'provider'
require_relative 'operation'
require_relative 'hard_constraints'
require_relative 'scoring_engine'
require_relative 'simulation_engine'
require_relative 'analytics_reporter'

module SmartRouter
  class Router
    attr_reader :providers, :strategy, :scoring_engine, :simulation_engine, :context

    def initialize(providers_data, strategy: 'combined', weights: nil, seed: 42)
      @providers = {}
      providers_data.each do |p_id, p_hash|
        @providers[p_id.to_s] = Provider.new(p_id, p_hash)
      end

      @strategy = strategy
      @scoring_engine = ScoringEngine.new(weights)
      @simulation_engine = SimulationEngine.new(seed: seed)

      @context = {
        total_operations_routed: 0,
        total_volume_routed: 0.0
      }
    end

    def route_queue(operations_data)
      decisions = []

      operations_data.each do |op_data|
        op = Operation.new(op_data)
        next unless op.valid?

        decision = route_single_operation(op)
        decisions << decision

        # Update context
        @context[:total_operations_routed] += 1
        @context[:total_volume_routed] = (@context[:total_volume_routed] + op.amount).round(8)
      end

      decisions
    end

    def route_single_operation(operation)
      attempts = []
      external_providers = @providers.values.reject(&:is_fallback)
      fallback_provider = @providers.values.find(&:is_fallback) || Provider.new('spacepayments', {
        'name' => 'SpacePayments Fallback',
        'status' => 'active',
        'limit_amount_min' => 0,
        'limit_amount_max' => 10_000_000,
        'daily_amount_limit' => 100_000_000,
        'available_requisites' => 100,
        'is_fallback' => true,
        'allow_negative_agreement' => true
      })

      # Evaluate hard constraints for external providers
      eligible_candidates = []
      skipped_attempts = []

      # Order providers consistently: by priority initially
      sorted_providers = external_providers.sort_by(&:priority)

      sorted_providers.each do |provider|
        is_eligible, reason, details = HardConstraints.check(provider, operation)
        if is_eligible
          eligible_candidates << provider
        else
          skipped_attempts << {
            'provider' => provider.id,
            'decision' => 'skipped',
            'reason' => reason,
            'details' => details
          }
        end
      end

      selected_provider = nil
      final_result = nil
      final_latency = 20

      if eligible_candidates.empty?
        # All external providers skipped -> Fallback directly to SpacePayments
        attempts.concat(skipped_attempts)

        selected_provider = fallback_provider
        sim_res, latency, err = @simulation_engine.execute_attempt(fallback_provider, operation)
        final_result = sim_res
        final_latency = latency

        attempts << {
          'provider' => fallback_provider.id,
          'decision' => 'selected',
          'reason' => 'fallback_all_providers_ineligible',
          'details' => 'Routed to internal fallback gateway spacepayments'
        }

        fallback_provider.reserve_in_progress!(operation.amount)
        fallback_provider.release_in_progress!(operation.amount, approved: (final_result == 'approved'))

      elsif eligible_candidates.size == 1
        # Exactly one provider passed hard constraints
        # Order skipped attempts before selected
        attempts.concat(skipped_attempts)

        candidate = eligible_candidates.first
        sim_res, latency, err = @simulation_engine.execute_attempt(candidate, operation)

        if sim_res == 'approved'
          selected_provider = candidate
          final_result = 'approved'
          final_latency = latency

          attempts << {
            'provider' => candidate.id,
            'decision' => 'selected',
            'reason' => 'only_eligible_provider'
          }

          candidate.reserve_in_progress!(operation.amount)
          candidate.release_in_progress!(operation.amount, approved: true)
        else
          # Single candidate failed -> fallback to spacepayments
          attempts << {
            'provider' => candidate.id,
            'decision' => 'skipped',
            'reason' => "simulated_#{sim_res}",
            'details' => err
          }

          selected_provider = fallback_provider
          fb_res, fb_lat, _ = @simulation_engine.execute_attempt(fallback_provider, operation)
          final_result = fb_res
          final_latency = fb_lat

          attempts << {
            'provider' => fallback_provider.id,
            'decision' => 'selected',
            'reason' => 'fallback_after_eligible_failure',
            'details' => "Fallback after #{candidate.id} #{sim_res}"
          }

          fallback_provider.reserve_in_progress!(operation.amount)
          fallback_provider.release_in_progress!(operation.amount, approved: (final_result == 'approved'))
        end

      else
        # Multiple candidates eligible -> Score and rank by strategy
        scored = eligible_candidates.map do |cand|
          score_info = @scoring_engine.score_provider(cand, operation, @context, @strategy)
          { provider: cand, score_info: score_info }
        end

        # Sort descending by score
        ranked_candidates = scored.sort_by { |item| -item[:score_info][:score] }

        # Cascade through ranked candidates
        success = false

        ranked_candidates.each_with_index do |item, idx|
          cand = item[:provider]
          score_info = item[:score_info]

          sim_res, latency, err = @simulation_engine.execute_attempt(cand, operation)

          if sim_res == 'approved'
            # Prepend skipped hard constraints
            attempts.concat(skipped_attempts) if attempts.empty?

            selected_provider = cand
            final_result = 'approved'
            final_latency = latency

            reason_desc = if ranked_candidates.size > 1 && score_info[:primary_factor]
                            score_info[:primary_factor]
                          else
                            'selected_by_strategy'
                          end

            attempts << {
              'provider' => cand.id,
              'decision' => 'selected',
              'reason' => reason_desc,
              'details' => score_info[:details]
            }

            cand.reserve_in_progress!(operation.amount)
            cand.release_in_progress!(operation.amount, approved: true)
            success = true
            break
          else
            # Candidate declined/timeout -> Cascade to next!
            attempts.concat(skipped_attempts) if attempts.empty?

            attempts << {
              'provider' => cand.id,
              'decision' => 'skipped',
              'reason' => "simulated_#{sim_res}",
              'details' => err || "Failed attempt on #{cand.id}"
            }
          end
        end

        unless success
          # All ranked candidates failed -> fallback to spacepayments
          selected_provider = fallback_provider
          fb_res, fb_lat, _ = @simulation_engine.execute_attempt(fallback_provider, operation)
          final_result = fb_res
          final_latency = fb_lat

          attempts << {
            'provider' => fallback_provider.id,
            'decision' => 'selected',
            'reason' => 'fallback_all_candidates_failed',
            'details' => 'All eligible candidates rejected or timed out, switched to fallback'
          }

          fallback_provider.reserve_in_progress!(operation.amount)
          fallback_provider.release_in_progress!(operation.amount, approved: (final_result == 'approved'))
        end
      end

      {
        'operation_id' => operation.operation_id,
        'selected_provider' => selected_provider ? selected_provider.id : 'spacepayments',
        'attempts' => attempts,
        'simulated_result' => final_result || 'approved',
        'latency_sec' => final_latency
      }
    end
  end
end
