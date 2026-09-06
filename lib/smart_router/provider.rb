# frozen_string_literal: true

module SmartRouter
  class Provider
    attr_reader :id, :name, :status, :traffic_percentage, :volume_share_pct,
                :priority, :limit_amount_min, :limit_amount_max,
                :daily_amount_limit, :daily_approved_amount,
                :in_progress_count_limit, :in_progress_count,
                :in_progress_amount_limit, :in_progress_amount,
                :available_requisites, :banks, :exclude_banks,
                :normalized_banks, :normalized_exclude_banks,
                :conversion_24h, :provider_margin_pct, :merchant_margin_pct,
                :requests_per_minute_limit, :current_requests_this_minute,
                :daily_turnover_min, :daily_turnover_max,
                :allow_negative_agreement, :avg_latency_sec, :is_fallback

    attr_accessor :processed_count, :processed_volume, :successful_count, :failed_count

    def initialize(id, data = {})
      data ||= {}
      @id = (id || data['payment_system'] || data[:payment_system]).to_s
      @name = data['name'] || data['payment_system'] || @id.capitalize
      @status = data['status'] || 'active'
      @traffic_percentage = (data['traffic_percentage'] || 0).to_f
      @volume_share_pct = (data['volume_share_pct'] || 0).to_f
      @priority = (data['priority'] || 10).to_i
      @limit_amount_min = (data['limit_amount_min'] || 0).to_f
      @limit_amount_max = (data['limit_amount_max'] || Float::INFINITY).to_f
      @daily_amount_limit = (data['daily_amount_limit'] || Float::INFINITY).to_f
      @daily_approved_amount = (data['daily_approved_amount'] || 0).to_f
      @in_progress_count_limit = (data['in_progress_count_limit'] || 50).to_i
      @in_progress_count = (data['in_progress_count'] || 0).to_i
      @in_progress_amount_limit = (data['in_progress_amount_limit'] || Float::INFINITY).to_f
      @in_progress_amount = (data['in_progress_amount'] || 0).to_f
      @available_requisites = (data['available_requisites'] || 10).to_i

      raw_banks = if data['banks'].is_a?(Array)
                    data['banks'].map(&:to_s).map(&:strip).map(&:downcase)
                  else
                    []
                  end
      @banks = raw_banks
      @normalized_banks = raw_banks.map { |b| Operation.normalize_bank(b) }

      raw_exclude = if data['exclude_banks'].is_a?(Array)
                      data['exclude_banks'].map(&:to_s).map(&:strip).map(&:downcase)
                    else
                      []
                    end
      @exclude_banks = raw_exclude
      @normalized_exclude_banks = raw_exclude.map { |b| Operation.normalize_bank(b) }

      @conversion_24h = (data['conversion_24h'] || 0.9).to_f
      @provider_margin_pct = (data['provider_margin_pct'] || 2.0).to_f
      @merchant_margin_pct = (data['merchant_margin_pct'] || 2.8).to_f
      @requests_per_minute_limit = (data['requests_per_minute_limit'] || 30).to_i
      @current_requests_this_minute = (data['current_requests_this_minute'] || 0).to_i
      @daily_turnover_min = (data['daily_turnover_min'] || 0).to_f
      @daily_turnover_max = (data['daily_turnover_max'] || @daily_amount_limit).to_f
      @allow_negative_agreement = data['allow_negative_agreement'] == true
      @avg_latency_sec = (data['avg_latency_sec'] || 20).to_i
      @is_fallback = data['is_fallback'] == true || @id == 'spacepayments'

      @processed_count = 0
      @processed_volume = 0.0
      @successful_count = 0
      @failed_count = 0
    end

    def active?
      @status == 'active'
    end

    def available_daily_budget
      [(@daily_amount_limit - @daily_approved_amount).round(8), 0.0].max
    end

    def daily_utilization_pct
      return 0.0 if @daily_amount_limit <= 0 || @daily_amount_limit.infinite?
      ((@daily_approved_amount / @daily_amount_limit) * 100.0).round(2)
    end

    def turnover_min_deficit
      [(@daily_turnover_min - @daily_approved_amount).round(8), 0.0].max
    end

    def turnover_min_reached?
      (@daily_approved_amount - @daily_turnover_min) >= -1e-9
    end

    def serves_bank?(bank_name)
      return false if excludes_bank?(bank_name)
      supports_bank?(bank_name)
    end

    def supports_bank?(bank_name)
      return true if @banks.empty?
      b = bank_name.to_s.downcase.strip
      norm = Operation.normalize_bank(b)
      @banks.include?(b) || @normalized_banks.include?(norm)
    end

    def excludes_bank?(bank_name)
      return false if @exclude_banks.empty?
      b = bank_name.to_s.downcase.strip
      norm = Operation.normalize_bank(b)
      @exclude_banks.include?(b) || @normalized_exclude_banks.include?(norm)
    end

    def margin_profitable?
      return true if @allow_negative_agreement
      (@provider_margin_pct - @merchant_margin_pct) <= 1e-9
    end

    def reserve_in_progress!(amount)
      @in_progress_count += 1
      @in_progress_amount = (@in_progress_amount + amount.to_f).round(8)
      @current_requests_this_minute += 1
    end

    def release_in_progress!(amount, approved: true)
      @in_progress_count = [@in_progress_count - 1, 0].max
      @in_progress_amount = [(@in_progress_amount - amount.to_f).round(8), 0.0].max
      @processed_count += 1
      @processed_volume = (@processed_volume + amount.to_f).round(8)

      if approved
        @daily_approved_amount = (@daily_approved_amount + amount.to_f).round(8)
        @available_requisites = [@available_requisites - 1, 0].max if @available_requisites > 0
        @successful_count += 1
      else
        @failed_count += 1
      end
    end

    def to_h
      {
        'name' => @name,
        'status' => @status,
        'traffic_percentage' => @traffic_percentage,
        'volume_share_pct' => @volume_share_pct,
        'priority' => @priority,
        'limit_amount_min' => @limit_amount_min,
        'limit_amount_max' => @limit_amount_max,
        'daily_amount_limit' => @daily_amount_limit,
        'daily_approved_amount' => @daily_approved_amount,
        'in_progress_count_limit' => @in_progress_count_limit,
        'in_progress_count' => @in_progress_count,
        'in_progress_amount_limit' => @in_progress_amount_limit,
        'in_progress_amount' => @in_progress_amount,
        'available_requisites' => @available_requisites,
        'banks' => @banks,
        'exclude_banks' => @exclude_banks,
        'conversion_24h' => @conversion_24h,
        'provider_margin_pct' => @provider_margin_pct,
        'merchant_margin_pct' => @merchant_margin_pct,
        'requests_per_minute_limit' => @requests_per_minute_limit,
        'current_requests_this_minute' => @current_requests_this_minute,
        'daily_turnover_min' => @daily_turnover_min,
        'daily_turnover_max' => @daily_turnover_max,
        'avg_latency_sec' => @avg_latency_sec,
        'allow_negative_agreement' => @allow_negative_agreement,
        'is_fallback' => @is_fallback
      }
    end
  end
end
