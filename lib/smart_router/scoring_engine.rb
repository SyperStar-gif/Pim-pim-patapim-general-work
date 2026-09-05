# frozen_string_literal: true

module SmartRouter
  class ScoringEngine
    DEFAULT_WEIGHTS = {
      traffic_share: 0.25,
      volume_share: 0.20,
      conversion: 0.20,
      financial_obligations: 0.15,
      amount_tier: 0.10,
      priority: 0.05,
      load_balance: 0.05
    }.freeze

    def initialize(weights = {})
      @weights = DEFAULT_WEIGHTS.merge(weights || {})
    end

    # Computes composite score and breakdown for eligible provider
    def score_provider(provider, operation, context, strategy_name = 'combined')
      case strategy_name.to_s
      when 'traffic_share'
        score = traffic_share_component(provider, context)
        { score: score, primary_factor: 'traffic_percentage_deficit', details: "Traffic share deficit: #{score.round(2)}" }

      when 'volume_share'
        score = volume_share_component(provider, context)
        { score: score, primary_factor: 'volume_share_deficit', details: "Volume share deficit: #{score.round(2)}" }

      when 'cascade_priority'
        # Lower priority number = higher score
        score = (100 - (provider.priority * 10)).to_f
        { score: score, primary_factor: 'cascade_priority', details: "Cascade priority: #{provider.priority}" }

      when 'amount_tier'
        score = amount_tier_component(provider, operation)
        { score: score, primary_factor: 'amount_tier_affinity', details: "Amount tier score: #{score.round(2)}" }

      when 'conversion_boost'
        score = provider.conversion_24h * 100.0
        { score: score, primary_factor: 'conversion_24h', details: "Conversion 24h: #{(provider.conversion_24h * 100).round(1)}%" }

      when 'rate_limit_intensity'
        remaining_rpm = [provider.requests_per_minute_limit - provider.current_requests_this_minute, 0].max
        score = (remaining_rpm.to_f / [provider.requests_per_minute_limit, 1].max) * 100.0
        { score: score, primary_factor: 'rate_headroom', details: "Available RPM headroom: #{remaining_rpm}/#{provider.requests_per_minute_limit}" }

      when 'financial_obligations'
        score = financial_obligation_component(provider)
        deficit = provider.turnover_min_deficit
        deficit_fmt = (deficit == deficit.to_i && deficit.abs >= 1) ? deficit.to_i : deficit.round(4)
        { score: score, primary_factor: 'turnover_min_commitment', details: "Turnover commitment deficit: #{deficit_fmt} RUB" }

      else # 'combined'
        comp_traffic = traffic_share_component(provider, context)
        comp_volume = volume_share_component(provider, context)
        comp_conversion = provider.conversion_24h * 100.0
        comp_financial = financial_obligation_component(provider)
        comp_tier = amount_tier_component(provider, operation)
        comp_priority = (100 - (provider.priority * 10)).to_f
        comp_load = (100.0 - provider.daily_utilization_pct)

        total_score = (
          (comp_traffic * @weights[:traffic_share]) +
          (comp_volume * @weights[:volume_share]) +
          (comp_conversion * @weights[:conversion]) +
          (comp_financial * @weights[:financial_obligations]) +
          (comp_tier * @weights[:amount_tier]) +
          (comp_priority * @weights[:priority]) +
          (comp_load * @weights[:load_balance])
        )

        breakdown = {
          traffic: comp_traffic.round(1),
          volume: comp_volume.round(1),
          conversion: comp_conversion.round(1),
          financial: comp_financial.round(1),
          tier: comp_tier.round(1),
          priority: comp_priority.round(1),
          load_headroom: comp_load.round(1)
        }

        # Identify key driver
        top_driver = if comp_financial > 150
                       'daily_turnover_min_deficit'
                     elsif comp_traffic > 70
                       'traffic_share_catch_up'
                     elsif comp_tier > 80
                       'optimal_amount_tier'
                     else
                       'highest_composite_score'
                     end

        { score: total_score, primary_factor: top_driver, details: "Composite score: #{total_score.round(2)} (#{breakdown})" }
      end
    end

    private

    def traffic_share_component(provider, context)
      target_pct = provider.traffic_percentage
      return 0.0 if target_pct <= 0

      total_routed = context[:total_operations_routed] || 0
      provider_routed = provider.processed_count

      if total_routed <= 0
        return 50.0 + target_pct
      end

      actual_pct = (provider_routed.to_f / total_routed) * 100.0
      # Deficit: positive if under-represented, negative if over-represented
      deficit = target_pct - actual_pct
      (50.0 + (deficit * 2.0)).clamp(0.0, 150.0)
    end

    def volume_share_component(provider, context)
      target_pct = provider.volume_share_pct
      return 0.0 if target_pct <= 0

      total_vol = context[:total_volume_routed] || 0.0
      provider_vol = provider.processed_volume

      if total_vol <= 1e-9
        return 50.0 + target_pct
      end

      actual_pct = (provider_vol.to_f / total_vol) * 100.0
      deficit = target_pct - actual_pct
      (50.0 + (deficit * 2.0)).clamp(0.0, 150.0)
    end

    def amount_tier_component(provider, operation)
      amt = operation.amount
      p_id = provider.id.downcase

      # Tier guidelines from hackathon brief:
      # 500–50,000 -> payflow
      # 50,001–100,000 -> vipay
      # >100,000 -> quickpay
      if amt <= 50_000
        return 100.0 if p_id == 'payflow'
        return 70.0 if p_id == 'vipay'
        return 40.0
      elsif amt <= 100_000
        return 100.0 if p_id == 'vipay'
        return 60.0 if p_id == 'quickpay'
        return 30.0
      else
        return 100.0 if p_id == 'quickpay'
        return 40.0 if p_id == 'spacepayments'
        return 10.0
      end
    end

    def financial_obligation_component(provider)
      return 50.0 if provider.daily_turnover_min <= 1e-9

      deficit = provider.turnover_min_deficit
      if deficit > 1e-9
        pct_remaining = (deficit.to_f / provider.daily_turnover_min) * 100.0
        100.0 + pct_remaining
      else
        40.0 # Fulfilled minimum commitment
      end
    end
  end
end
