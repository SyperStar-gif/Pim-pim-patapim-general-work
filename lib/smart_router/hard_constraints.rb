# frozen_string_literal: true

module SmartRouter
  class HardConstraints
    EPSILON = 1e-9

    def self.less_than?(a, b)
      (a - b) < -EPSILON
    end

    def self.greater_than?(a, b)
      (a - b) > EPSILON
    end

    def self.format_amount(val)
      return '0' if val.nil? || val.zero?
      if val == val.to_i && val.abs >= 1
        val.to_i.to_s
      else
        sprintf('%.8f', val).sub(/\.?0+$/, '')
      end
    end

    # Evaluates provider against operation constraints
    # Returns [eligible: Boolean, reason: String, details: String]
    def self.check(provider, operation)
      amount = operation.amount
      bank = operation.bank

      # 0. Basic amount positivity check
      if amount <= 0
        return [false, 'invalid_amount', "Amount #{format_amount(amount)} must be strictly positive"]
      end

      # 1. Provider status
      unless provider.active?
        return [false, 'provider_inactive', "status '#{provider.status}' != 'active'"]
      end

      # 2. Minimum amount limit (with epsilon protection against IEEE 754 precision issues)
      if less_than?(amount, provider.limit_amount_min)
        return [
          false,
          'amount_below_min',
          "#{format_amount(amount)} < limit_amount_min #{format_amount(provider.limit_amount_min)}"
        ]
      end

      # 3. Maximum amount limit (with epsilon protection)
      if greater_than?(amount, provider.limit_amount_max)
        return [
          false,
          'amount_exceeds_limit',
          "#{format_amount(amount)} > limit_amount_max #{format_amount(provider.limit_amount_max)}"
        ]
      end

      # 4. Daily budget limit (with epsilon protection)
      if greater_than?(provider.daily_approved_amount + amount, provider.daily_amount_limit)
        return [
          false,
          'daily_limit_exceeded',
          "#{format_amount(provider.daily_approved_amount)} + #{format_amount(amount)} > daily_amount_limit #{format_amount(provider.daily_amount_limit)}"
        ]
      end

      # 5. In-progress concurrent count limit
      if (provider.in_progress_count + 1) > provider.in_progress_count_limit
        return [
          false,
          'in_progress_count_limit_reached',
          "#{provider.in_progress_count + 1} > limit #{provider.in_progress_count_limit}"
        ]
      end

      # 6. In-progress amount limit (with epsilon protection)
      if greater_than?(provider.in_progress_amount + amount, provider.in_progress_amount_limit)
        return [
          false,
          'in_progress_amount_limit_reached',
          "#{format_amount(provider.in_progress_amount + amount)} > limit #{format_amount(provider.in_progress_amount_limit)}"
        ]
      end

      # 7. Bank exclusion blacklist
      if provider.excludes_bank?(bank)
        return [false, 'bank_excluded', "bank '#{bank}' is explicitly excluded"]
      end

      # 8. Bank support whitelist
      if !provider.supports_bank?(bank)
        return [false, 'bank_not_in_list', "bank '#{bank}' not in allowed list"]
      end

      # 9. Margin agreement check
      unless provider.margin_profitable?
        return [
          false,
          'margin_agreement_negative',
          "provider margin #{provider.provider_margin_pct}% > merchant #{provider.merchant_margin_pct}%"
        ]
      end

      # 10. Available requisites / terminals
      if provider.available_requisites <= 0
        return [false, 'no_available_requisites', "available_requisites = 0"]
      end

      # 11. Rate limit (intensity)
      if (provider.current_requests_this_minute + 1) > provider.requests_per_minute_limit
        return [
          false,
          'rate_limit_exceeded',
          "RPM limit reached (#{provider.requests_per_minute_limit}/min)"
        ]
      end

      [true, 'eligible', 'All hard-constraints satisfied']
    end
  end
end
