#!/usr/bin/env ruby
# frozen_string_literal: true

# Скрипт проверки решений участников для кейса "Роутинг выплатного трафика".
# Использование:
#   ruby scripts/validate_10.rb path/to/routing_decisions.json

require 'json'

DATA_DIR = File.expand_path('../data', __dir__)
QUEUE_FILENAME = 'operations_queue.json'

def load_json(filename)
  filepath = File.join(DATA_DIR, filename)
  filepath = File.expand_path(filename, __dir__) unless File.exist?(filepath)
  JSON.parse(File.read(filepath))
end

def eligible_providers(operation, providers)
  amount = operation['amount']
  bank = operation['bank']

  providers.select do |p|
    next false if p['status'] != 'active'
    next false if p['traffic_percentage'].to_f.zero? && p['payment_system'] != 'spacepayments'
    next false if p['limit_amount_min'] && amount < p['limit_amount_min']
    next false if p['limit_amount_max'] && amount > p['limit_amount_max']
    next false if p['daily_amount_limit'] && (p['daily_approved_amount'].to_f + amount) > p['daily_amount_limit']
    next false if p['in_progress_count_limit'] && (p['in_progress_count'].to_i + 1) > p['in_progress_count_limit']
    next false if p['in_progress_amount_limit'] && (p['in_progress_amount'].to_f + amount) > p['in_progress_amount_limit']
    next false if p['available_requisites'].to_i.zero?
    next false if p['provider_margin_pct'].to_f > p['merchant_margin_pct'].to_f && !p['allow_negative_agreement']

    banks = p['banks'] || []
    if banks.any?
      if p['exclude_banks'] && !p['exclude_banks'].empty?
        next false if p['exclude_banks'].include?(bank)
      end
      next false unless banks.include?(bank)
    end

    true
  end.map { |p| p['payment_system'] }
end

def validate_structure(decision)
  errors = []
  %w[operation_id selected_provider attempts].each do |field|
    errors << "отсутствует поле #{field}" unless decision.key?(field)
  end

  if decision['attempts']
    decision['attempts'].each_with_index do |attempt, i|
      %w[provider decision reason].each do |field|
        errors << "attempts[#{i}]: отсутствует #{field}" unless attempt.key?(field)
      end
      unless %w[selected skipped].include?(attempt['decision'])
        errors << "attempts[#{i}]: decision должен быть selected или skipped"
      end
    end
  end

  errors
end

# --- main ---

if ARGV.empty?
  puts "Использование: ruby scripts/validate_10.rb <routing_decisions.json>"
  exit 1
end

decisions_path = ARGV[0]
unless File.exist?(decisions_path)
  puts "❌ Файл не найден: #{decisions_path}"
  exit 1
end

begin
  decisions = JSON.parse(File.read(decisions_path))
rescue JSON::ParserError => e
  puts "❌ Невалидный JSON: #{e.message}"
  exit 1
end

decisions = [decisions] unless decisions.is_a?(Array)

# Try loading operations_queue_10.json or fallback to operations_queue_test.json / operations_queue.json
queue_file = if File.exist?(File.join(DATA_DIR, 'operations_queue_10.json'))
  'operations_queue_10.json'
elsif File.exist?('operations_queue_test.json')
  'operations_queue_test.json'
else
  'operations_queue.json'
end

queue = if queue_file.start_with?('/') || File.exist?(queue_file)
  JSON.parse(File.read(queue_file))
else
  load_json(queue_file)
end

providers_data = load_json('providers.json')
providers = if providers_data.is_a?(Hash) && providers_data.key?('providers')
  providers_data['providers']
elsif providers_data.is_a?(Hash)
  providers_data.map { |k, v| v.merge('payment_system' => k) }
else
  providers_data
end

# Load reference decisions if exists, otherwise construct standard deterministic rules
reference = if File.exist?(File.join(DATA_DIR, 'reference_decisions.json'))
  load_json('reference_decisions.json')
elsif File.exist?('reference_decisions.json')
  JSON.parse(File.read('reference_decisions.json'))
else
  {
    'deterministic_cases' => [
      { 'operation_id' => 'op_103', 'required_provider' => 'quickpay', 'reason' => 'Only quickpay supports 150000 RUB' },
      { 'operation_id' => 'op_104', 'required_provider' => 'payflow', 'reason' => 'Only payflow supports gazprombank for 8000 RUB' },
      { 'operation_id' => 'op_107', 'required_provider' => 'quickpay', 'reason' => 'Only quickpay supports 210000 RUB' },
      { 'operation_id' => 'op_110', 'required_provider' => 'spacepayments', 'reason' => '450000 RUB exceeds all external providers' }
    ],
    'skip_reasons_expected' => {
      'op_103' => { 'vipay' => 'amount_exceeds_limit', 'payflow' => 'amount_exceeds_limit' },
      'op_104' => { 'vipay' => 'bank_excluded', 'quickpay' => 'amount_below_min' },
      'op_107' => { 'vipay' => 'amount_exceeds_limit', 'payflow' => 'amount_exceeds_limit' },
      'op_110' => { 'vipay' => 'amount_exceeds_limit', 'payflow' => 'amount_exceeds_limit', 'quickpay' => 'amount_exceeds_limit' }
    }
  }
end

queue_ids = queue.map { |op| op['operation_id'] }
decision_ids = decisions.map { |d| d['operation_id'] }

passed = 0
failed = 0
warnings = 0

puts "=== Проверка routing_decisions.json ==="
puts "Заявок в очереди: #{queue_ids.size}"
puts "Решений в файле:  #{decision_ids.size}"
puts

# 1. Покрытие
missing = queue_ids - decision_ids
extra = decision_ids - queue_ids

if missing.any?
  puts "❌ Отсутствуют решения для: #{missing.join(', ')}"
  failed += missing.size
else
  puts "✅ Все заявки из очереди покрыты"
  passed += 1
end

if extra.any?
  puts "⚠️  Лишние operation_id: #{extra.join(', ')}"
  warnings += 1
end

# 2. Структура
structure_errors = []
decisions.each do |d|
  structure_errors.concat(validate_structure(d).map { |e| "#{d['operation_id']}: #{e}" })
end

if structure_errors.any?
  puts "❌ Ошибки структуры:"
  structure_errors.each { |e| puts "   #{e}" }
  failed += structure_errors.size
else
  puts "✅ Структура JSON корректна"
  passed += 1
end

# 3. Детерминированные кейсы
reference['deterministic_cases']&.select { |case_| queue_ids.include?(case_['operation_id']) }&.each do |case_|
  op_id = case_['operation_id']
  required = case_['required_provider']
  decision = decisions.find { |d| d['operation_id'] == op_id }

  unless decision
    puts "❌ #{op_id}: нет решения (ожидался #{required})"
    failed += 1
    next
  end

  if decision['selected_provider'] == required
    puts "✅ #{op_id}: корректно выбран #{required}"
    passed += 1
  else
    puts "❌ #{op_id}: выбран #{decision['selected_provider']}, ожидался #{required}"
    puts "   Причина: #{case_['reason']}"
    failed += 1
  end
end

# 4. Eligible providers
queue.each do |operation|
  op_id = operation['operation_id']
  decision = decisions.find { |d| d['operation_id'] == op_id }
  next unless decision

  eligible = eligible_providers(operation, providers)
  selected = decision['selected_provider']

  if eligible.include?(selected)
    puts "✅ #{op_id}: #{selected} в списке допустимых [#{eligible.join(', ')}]"
    passed += 1
  else
    puts "❌ #{op_id}: #{selected} НЕ допустим. Допустимые: [#{eligible.join(', ')}]"
    failed += 1
  end
end

# 5. Проверка skip reasons для известных кейсов
reference['skip_reasons_expected']&.each do |op_id, skips|
  next unless queue_ids.include?(op_id)

  decision = decisions.find { |d| d['operation_id'] == op_id }
  next unless decision

  skips.each do |provider, expected_reason|
    attempt = decision['attempts']&.find { |a| a['provider'] == provider }
    if attempt.nil?
      puts "⚠️  #{op_id}: нет attempt для #{provider} (ожидался skip: #{expected_reason})"
      warnings += 1
    elsif attempt['decision'] != 'skipped'
      puts "⚠️  #{op_id}: #{provider} не skipped (ожидался skip: #{expected_reason})"
      warnings += 1
    else
      puts "✅ #{op_id}: #{provider} корректно skipped (#{attempt['reason']})"
      passed += 1
    end
  end
end

puts
puts "=== Итого ==="
puts "✅ Пройдено: #{passed}"
puts "❌ Ошибок:   #{failed}"
puts "⚠️  Предупр.: #{warnings}"

exit(failed.zero? ? 0 : 1)
