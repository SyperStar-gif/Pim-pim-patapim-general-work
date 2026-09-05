# frozen_string_literal: true

require 'json'
require_relative 'precision_math'

module SmartRouter
  # MultiCurrencyRouter converts and routes multi-currency payments (RUB, USD, EUR, USDT)
  # using real-time or pegged exchange rates, applying individual currency limits.
  class MultiCurrencyRouter
    DEFAULT_RATES = {
      'RUB' => 1.0,
      'USD' => 92.5,
      'EUR' => 100.2,
      'USDT' => 93.0
    }.freeze

    attr_reader :exchange_rates

    def initialize(custom_rates = nil)
      @exchange_rates = custom_rates || DEFAULT_RATES.dup
    end

    def update_rate(currency, rate_in_rub)
      @exchange_rates[currency.to_s.upcase] = rate_in_rub.to_f
    end

    def convert_to_rub(amount, currency = 'RUB')
      curr = currency.to_s.upcase
      rate = @exchange_rates[curr] || 1.0
      PrecisionMath.mul(amount, rate).to_f
    end

    def convert_from_rub(amount_rub, target_currency)
      curr = target_currency.to_s.upcase
      rate = @exchange_rates[curr] || 1.0
      return 0.0 if rate.zero?

      PrecisionMath.div(amount_rub, rate).to_f
    end

    # Normalizes an incoming operation payload to RUB base amount
    def normalize_operation(operation_hash)
      op = operation_hash.dup
      curr = (op['currency'] || op[:currency] || 'RUB').to_s.upcase
      raw_amount = (op['amount'] || op[:amount]).to_f

      if curr != 'RUB'
        rub_amount = convert_to_rub(raw_amount, curr)
        op['original_amount'] = raw_amount
        op['original_currency'] = curr
        op['amount'] = rub_amount
        op['currency'] = 'RUB'
      end
      op
    end
  end
end
