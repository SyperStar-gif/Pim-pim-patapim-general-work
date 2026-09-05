# frozen_string_literal: true

require 'json'
require 'bigdecimal'

module SmartRouter
  # PrecisionMath provides exact decimal arithmetic for financial routing,
  # avoiding IEEE-754 floating point inaccuracies and rounding artifacts.
  module PrecisionMath
    EPSILON = 1e-9
    PRECISION_DIGITS = 12

    class << self
      def to_d(val)
        case val
        when BigDecimal then val
        when Integer then BigDecimal(val)
        when Float
          # Convert via string representation to avoid float mantissa noise
          BigDecimal(val.to_s)
        when String
          cleaned = val.strip
          cleaned = '0' if cleaned.empty?
          BigDecimal(cleaned)
        when nil then BigDecimal(0)
        else BigDecimal(val.to_s)
        end
      rescue ArgumentError
        BigDecimal(0)
      end

      def add(a, b)
        (to_d(a) + to_d(b)).round(PRECISION_DIGITS)
      end

      def sub(a, b)
        (to_d(a) - to_d(b)).round(PRECISION_DIGITS)
      end

      def mul(a, b)
        (to_d(a) * to_d(b)).round(PRECISION_DIGITS)
      end

      def div(a, b)
        denom = to_d(b)
        return BigDecimal(0) if denom.zero?

        (to_d(a) / denom).round(PRECISION_DIGITS)
      end

      def safe_pct(num, denom)
        d = to_d(denom)
        return 0.0 if d.zero?

        ((to_d(num) / d) * 100).to_f.round(4)
      end

      def gte?(a, b)
        to_d(a) >= to_d(b) - BigDecimal(EPSILON.to_s)
      end

      def lte?(a, b)
        to_d(a) <= to_d(b) + BigDecimal(EPSILON.to_s)
      end

      def gt?(a, b)
        to_d(a) > to_d(b) + BigDecimal(EPSILON.to_s)
      end

      def lt?(a, b)
        to_d(a) < to_d(b) - BigDecimal(EPSILON.to_s)
      end

      def eq?(a, b)
        (to_d(a) - to_d(b)).abs <= BigDecimal(EPSILON.to_s)
      end

      def format_amount(val)
        d = to_d(val)
        if d == d.to_i
          d.to_i.to_s
        else
          # strip trailing zeroes after decimal
          d.to_s('F').sub(/\.?0+$/, '')
        end
      end
    end
  end
end
