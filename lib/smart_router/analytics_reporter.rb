# frozen_string_literal: true

require 'date'

module SmartRouter
  class AnalyticsReporter
    def self.format_num(val)
      return 0 if val.nil? || val.zero?
      if val == val.to_i && val.abs >= 1
        val.to_i
      else
        val.round(8)
      end
    end

    def self.generate_report(decisions, providers, period: nil)
      period ||= Date.today.to_s
      total_operations = decisions.size

      # Distribution
      counts = Hash.new(0)
      volumes = Hash.new(0.0)
      skip_reasons = Hash.new(0)

      decisions.each do |dec|
        p_id = dec['selected_provider']
        counts[p_id] += 1

        attempts = dec['attempts'] || []
        attempts.each do |att|
          if att['decision'] == 'skipped'
            reason = att['reason'] || 'unknown_reason'
            skip_reasons[reason] += 1
          end
        end
      end

      # Provider distributions
      distribution = {}
      projected_daily_utilization = {}
      volume_distribution = {}

      # Total volume across providers
      providers.each do |p_id, p|
        next if p.is_fallback && counts[p_id] == 0

        p_count = counts[p_id]
        share_pct = total_operations > 0 ? ((p_count.to_f / total_operations) * 100.0).round(1) : 0.0

        distribution[p_id] = {
          'count' => p_count,
          'share_pct' => share_pct,
          'target_pct' => p.traffic_percentage
        }

        util_pct = p.daily_utilization_pct
        projected_daily_utilization[p_id] = {
          'used' => format_num(p.daily_approved_amount),
          'limit' => format_num(p.daily_amount_limit),
          'utilization_pct' => util_pct
        }

        volume_distribution[p_id] = {
          'processed_volume' => format_num(p.processed_volume),
          'daily_approved_amount' => format_num(p.daily_approved_amount),
          'target_volume_pct' => p.volume_share_pct
        }
      end

      # Generate smart recommendations
      recommendations = []

      providers.each do |p_id, p|
        next if p.is_fallback

        util_pct = p.daily_utilization_pct
        if util_pct >= 80.0
          recommendations << "#{p_id} близок к дневному лимиту (#{util_pct}%) — рекомендуется временно снизить traffic_percentage или запросить расширение дневного лимита"
        elsif util_pct >= 65.0
          recommendations << "#{p_id} достиг #{util_pct}% дневного лимита — отслеживать интенсивность трафика"
        end

        # Minimum turnover guarantee
        if p.daily_turnover_min > 0 && p.daily_approved_amount < p.daily_turnover_min
          deficit = p.daily_turnover_min - p.daily_approved_amount
          deficit_fmt = format_num(deficit)
          recommendations << "#{p_id} имеет финансовое обязательство (дефицит #{deficit_fmt} ₽) — приоритезировать подходящие чеки для выполнения суточного минимума"
        end

        # Deviation from target
        dist = distribution[p_id]
        if dist
          diff = dist['share_pct'] - dist['target_pct']
          if diff < -15.0
            reasons_summary = []
            reasons_summary << 'лимиты по сумме' if skip_reasons['amount_exceeds_limit'].to_i > 0
            reasons_summary << 'банковские фильтры' if (skip_reasons['bank_not_in_list'].to_i + skip_reasons['bank_excluded'].to_i) > 0
            reasons_str = reasons_summary.any? ? " (причины: #{reasons_summary.join(', ')})" : ''
            recommendations << "#{p_id} отстает от целевой доли (#{dist['share_pct']}% против #{dist['target_pct']}%)#{reasons_str} — скорректировать фильтры или веса"
          elsif diff > 15.0
            recommendations << "#{p_id} превышает целевую долю трафика (+#{diff.round(1)}%) из-за отсутствия альтернатив на крупных чеках"
          end
        end
      end

      if skip_reasons['amount_exceeds_limit'].to_i >= 3
        recommendations << "Высокая доля отклонений amount_exceeds_limit (#{skip_reasons['amount_exceeds_limit']}) — рекомендуется подключить провайдеров с чеками 100k+ или повысить лимит vipay"
      end

      if skip_reasons['bank_excluded'].to_i + skip_reasons['bank_not_in_list'].to_i >= 3
        recommendations << "Частые пропуски по банкам — пересмотреть exclude_banks для оптимизации покрытия платежных методов"
      end

      {
        'period' => period,
        'total_operations' => total_operations,
        'distribution' => distribution,
        'skip_reasons' => skip_reasons,
        'projected_daily_utilization' => projected_daily_utilization,
        'recommendations' => recommendations
      }
    end
  end
end
