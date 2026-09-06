# frozen_string_literal: true

module SmartRouter
  class Operation
    attr_reader :operation_id, :amount, :bank, :client_id, :created_at, :raw_data

    def self.normalize_bank(b)
      normalized = b.to_s.downcase.strip
      case normalized
      when 'sberbank', 'sber', 'сбербанк', 'сбер'
        'sber'
      when 'tinkoff', 'tbank', 't-bank', 'тинькофф', 'т-банк', 'тбанк'
        'tbank'
      when 'alfa', 'alfabank', 'alfa-bank', 'альфа', 'альфа-банк', 'альфабанк'
        'alfa'
      when 'raiffeisen', 'raif', 'raiffeisenbank', 'райффайзен', 'райффайзенбанк', 'райф'
        'raiffeisen'
      when 'gazprom', 'gazprombank', 'gpb', 'газпром', 'газпромбанк', 'гпб'
        'gazprombank'
      when 'vtb', 'vtb24', 'втб', 'втб24'
        'vtb'
      when 'ozon', 'ozonbank', 'озон', 'озонбанк'
        'ozon'
      else
        normalized
      end
    end

    def initialize(data)
      @raw_data = data
      @operation_id = (data['operation_id'] || data[:operation_id]).to_s.strip
      raw_amount = data['amount'] || data[:amount] || 0
      @amount = raw_amount.to_s.strip.to_f.round(8)

      # Determine bank from explicit bank field or payout_requisite SBP bank_name
      raw_bank = (data['bank'] || data[:bank] || '').to_s.downcase.strip
      if raw_bank.empty? && data['payout_requisite'] && data['payout_requisite']['sbp']
        raw_bank = data['payout_requisite']['sbp']['bank_name'].to_s.downcase.strip
      end

      @bank = self.class.normalize_bank(raw_bank)
      @client_id = (data['client_id'] || data[:client_id] || @operation_id).to_s.strip
      @created_at = (data['created_at'] || data[:created_at] || Time.now.iso8601).to_s.strip
    end

    def valid?
      !@operation_id.empty? && @amount > 1e-9 && !@bank.empty?
    end

    def to_h
      formatted_amount = (@amount == @amount.to_i && @amount.abs >= 1) ? @amount.to_i : @amount
      {
        'operation_id' => @operation_id,
        'amount' => formatted_amount,
        'bank' => @bank,
        'client_id' => @client_id,
        'created_at' => @created_at
      }
    end
  end
end
