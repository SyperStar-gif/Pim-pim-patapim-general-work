# frozen_string_literal: true

module SmartRouter
  class Operation
    attr_reader :operation_id, :amount, :bank, :client_id, :created_at, :raw_data

    def initialize(data)
      @raw_data = data
      @operation_id = (data['operation_id'] || data[:operation_id]).to_s.strip
      raw_amount = data['amount'] || data[:amount] || 0
      @amount = raw_amount.to_s.strip.to_f.round(8)
      @bank = (data['bank'] || data[:bank] || '').to_s.downcase.strip
      @client_id = (data['client_id'] || data[:client_id]).to_s.strip
      @created_at = (data['created_at'] || data[:created_at]).to_s.strip
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
