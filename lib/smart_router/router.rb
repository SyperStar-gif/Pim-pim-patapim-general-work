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

      list = if providers_data.is_a?(Hash) && providers_data.key?('providers') && providers_data['providers'].is_a?(Array)
               providers_data['providers']
             elsif providers_data.is_a?(Array)
               providers_data
             elsif providers_data.is_a?(Hash)
               providers_data.map do |k, v|
                 v.is_a?(Hash) ? v.merge('payment_system' => k) : nil
               end.compact
             else
               []
             end

      list.each do |p_hash|
        next unless p_hash.is_a?(Hash)
        p_id = (p_hash['payment_system'] || p_hash[:payment_system] || p_hash['id'] || p_hash[:id]).to_s
        @providers[p_id] = Provider.new(p_id, p_hash)
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

    def route_single(op_or_hash)
      op = op_or_hash.is_a?(Operation) ? op_or_hash : Operation.new(op_or_hash)
      route_single_operation(op)
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
      skipped_attempts = {}

      # Order providers consistently: by priority initially
      sorted_providers = external_providers.sort_by(&:priority)

      sorted_providers.each do |provider|
        is_eligible, reason, details = HardConstraints.check(provider, operation)
        if is_eligible
          eligible_candidates << provider
        else
          norm_reason = (reason == 'amount_below_min') ? 'amount_below_minimum' : reason
          att_data = {
            'provider' => provider.id,
            'decision' => 'skipped',
            'reason' => norm_reason
          }
          att_data['details'] = details if details && !details.to_s.strip.empty?
          skipped_attempts[provider.id] = att_data
        end
      end

      selected_provider = nil
      final_result = nil
      final_latency = 30

      if eligible_candidates.empty?
        # All external providers skipped -> Fallback directly to SpacePayments
        attempts = sorted_providers.map { |p| skipped_attempts[p.id] }.compact

        selected_provider = fallback_provider
        sim_res, latency, err = @simulation_engine.execute_attempt(fallback_provider, operation)
        final_result = sim_res
        final_latency = latency

        attempts << {
          'provider' => fallback_provider.id,
          'decision' => 'selected',
          'reason' => 'fallback_all_providers_ineligible'
        }

        fallback_provider.reserve_in_progress!(operation.amount)
        fallback_provider.release_in_progress!(operation.amount, approved: (final_result == 'approved'))

      else
        # Candidates passed hard constraints
        scored = eligible_candidates.map do |cand|
          score_info = @scoring_engine.score_provider(cand, operation, @context, @strategy)
          { provider: cand, score_info: score_info }
        end

        ranked_candidates = scored.sort_by { |item| -item[:score_info][:score] }

        chosen_candidate = nil
        failed_simulations = []

        ranked_candidates.each do |item|
          cand = item[:provider]
          sim_res, latency, err = @simulation_engine.execute_attempt(cand, operation)

          if sim_res == 'approved'
            chosen_candidate = cand
            final_result = 'approved'
            final_latency = latency
            break
          else
            failed_simulations << {
              'provider' => cand.id,
              'decision' => 'skipped',
              'reason' => "simulated_#{sim_res}"
            }
          end
        end

        if chosen_candidate
          selected_provider = chosen_candidate
          sel_reason = (eligible_candidates.size == 1) ? 'only_eligible_provider' : 'first_eligible'

          # Build attempts: list providers in sorted_providers order
          sorted_providers.each do |p|
            if p.id == chosen_candidate.id
              attempts << {
                'provider' => p.id,
                'decision' => 'selected',
                'reason' => sel_reason
              }
            elsif skipped_attempts.key?(p.id)
              attempts << skipped_attempts[p.id]
            elsif failed_simulations.any? { |fs| fs['provider'] == p.id }
              attempts << failed_simulations.find { |fs| fs['provider'] == p.id }
            end
          end

          chosen_candidate.reserve_in_progress!(operation.amount)
          chosen_candidate.release_in_progress!(operation.amount, approved: true)
        else
          # All ranked candidates failed simulation -> fallback to spacepayments
          attempts = sorted_providers.map { |p| skipped_attempts[p.id] }.compact + failed_simulations
          selected_provider = fallback_provider
          fb_res, fb_lat, _ = @simulation_engine.execute_attempt(fallback_provider, operation)
          final_result = fb_res
          final_latency = fb_lat

          attempts << {
            'provider' => fallback_provider.id,
            'decision' => 'selected',
            'reason' => 'fallback_all_candidates_failed'
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
