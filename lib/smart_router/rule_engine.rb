# frozen_string_literal: true

require 'json'
require 'time'
require_relative 'precision_math'

module SmartRouter
  # RuleEngine allows dynamic definition, serialization, and evaluation
  # of custom business routing rules without modifying core engine logic.
  class RuleEngine
    attr_reader :rules

    def initialize(rules_json = nil)
      @rules = []
      load_rules(rules_json) if rules_json
    end

    def add_rule(name:, condition_block:, action_block:, priority: 10, enabled: true)
      @rules << {
        name: name,
        condition: condition_block,
        action: action_block,
        priority: priority,
        enabled: enabled
      }
      @rules.sort_by! { |r| -r[:priority] }
    end

    def load_rules(rules_json)
      parsed = rules_json.is_a?(String) ? JSON.parse(rules_json) : rules_json
      parsed.each do |r|
        add_rule(
          name: r['name'],
          condition_block: build_condition(r['condition']),
          action_block: build_action(r['action']),
          priority: r['priority'] || 10,
          enabled: r.fetch('enabled', true)
        )
      end
    end

    def evaluate_pre_filters(operation, providers)
      # Evaluates rules before candidate ranking
      active_rules = @rules.select { |r| r[:enabled] }
      candidates = providers.dup

      active_rules.each do |rule|
        begin
          if rule[:condition].call(operation, candidates)
            candidates = rule[:action].call(operation, candidates)
          end
        rescue StandardError => e
          # Graceful degradation on custom rule error
          warn "[RuleEngine Warning] Rule '#{rule[:name]}' raised: #{e.message}"
        end
      end

      candidates
    end

    private

    def build_condition(cond_spec)
      return ->(_op, _provs) { true } unless cond_spec

      lambda do |operation, _providers|
        field = cond_spec['field']
        operator = cond_spec['operator']
        value = cond_spec['value']

        op_val = operation.respond_to?(field) ? operation.public_send(field) : operation[field]

        case operator
        when '==' then op_val == value
        when '!=' then op_val != value
        when '>' then PrecisionMath.gt?(op_val, value)
        when '<' then PrecisionMath.lt?(op_val, value)
        when '>=' then PrecisionMath.gte?(op_val, value)
        when '<=' then PrecisionMath.lte?(op_val, value)
        when 'in' then Array(value).include?(op_val)
        when 'not_in' then !Array(value).include?(op_val)
        else true
        end
      end
    end

    def build_action(action_spec)
      return ->(_op, provs) { provs } unless action_spec

      lambda do |_operation, providers|
        type = action_spec['type']
        case type
        when 'filter_by_provider'
          allowed = Array(action_spec['allowed_providers'])
          providers.select { |p| allowed.include?(p.id) }
        when 'exclude_provider'
          excluded = Array(action_spec['excluded_providers'])
          providers.reject { |p| excluded.include?(p.id) }
        when 'boost_provider'
          # Tag provider for score boost in scoring engine
          target = action_spec['target_provider']
          boost = action_spec['boost_amount'] || 1.5
          providers.each do |p|
            p.custom_boost = boost if p.id == target
          end
          providers
        else
          providers
        end
      end
    end
  end
end
