import { RoutingReport } from '../types';
import { formatCurrency, formatPercent, REASON_TRANSLATIONS, safeSub } from '../lib/formatters';
import { ResponsiveContainer, BarChart, Bar, XAxis, YAxis, Tooltip, Legend, CartesianGrid, Cell } from 'recharts';
import { BarChart3, AlertCircle, TrendingUp, Lightbulb, ShieldAlert, CheckCircle2 } from 'lucide-react';

interface AnalyticsDashboardProps {
  report: RoutingReport | null;
}

export function AnalyticsDashboard({ report }: AnalyticsDashboardProps) {
  if (!report) {
    return (
      <div className="bg-white rounded-xl border border-slate-200 p-8 text-center text-slate-500 text-sm">
        Запустите роутинг для формирования аналитического отчета
      </div>
    );
  }

  // Distribution chart data
  const distData = Object.entries(report.distribution || {}).map(([pId, stats]) => ({
    provider: pId.toUpperCase(),
    actual: stats.share_pct,
    target: stats.target_pct,
    count: stats.count
  }));

  // Skip reasons data
  const skipData = Object.entries(report.skip_reasons || {}).map(([reason, count]) => {
    const label = REASON_TRANSLATIONS[reason]?.label || reason;
    return {
      reason: label,
      count,
      rawReason: reason
    };
  });

  return (
    <section className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <BarChart3 className="w-4 h-4 text-indigo-600" />
          <h2 className="text-sm font-bold text-slate-900">Аналитика качества роутинга и аудит лимитов</h2>
          <span className="text-xs text-slate-500 font-mono">
            Период: {report.period} • Всего операций: {report.total_operations}
          </span>
        </div>
      </div>

      {/* Top 3 Metric Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3.5">
        <div className="bg-white rounded-xl border border-slate-200 p-4 shadow-xs">
          <span className="text-xs text-slate-500 block">Всего обработано операций</span>
          <div className="flex items-baseline gap-2 mt-1">
            <span className="text-2xl font-bold text-slate-900">{report.total_operations}</span>
            <span className="text-xs text-emerald-600 font-medium">100% маршрутизировано</span>
          </div>
          <p className="text-[11px] text-slate-500 mt-1">
            Без зависших или потерянных транзакций
          </p>
        </div>

        <div className="bg-white rounded-xl border border-slate-200 p-4 shadow-xs">
          <span className="text-xs text-slate-500 block">Отклонения Hard-constraints</span>
          <div className="flex items-baseline gap-2 mt-1">
            <span className="text-2xl font-bold text-amber-600">
              {Object.values(report.skip_reasons || {}).reduce((a, b) => a + b, 0)}
            </span>
            <span className="text-xs text-slate-500">срабатываний фильтров</span>
          </div>
          <p className="text-[11px] text-slate-500 mt-1">
            Исключено попыток до выбора стратегии
          </p>
        </div>

        <div className="bg-white rounded-xl border border-slate-200 p-4 shadow-xs">
          <span className="text-xs text-slate-500 block">Выработка рекомендаций</span>
          <div className="flex items-baseline gap-2 mt-1">
            <span className="text-2xl font-bold text-indigo-600">
              {Array.isArray(report.recommendations) ? report.recommendations.length : 0}
            </span>
            <span className="text-xs text-indigo-600 font-medium">активных инсайта</span>
          </div>
          <p className="text-[11px] text-slate-500 mt-1">
            На основе лимитов, конверсии и банков
          </p>
        </div>
      </div>

      {/* Distribution Comparison Table and Chart */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Actual vs Target Chart */}
        <div className="bg-white rounded-xl border border-slate-200 p-4 shadow-xs space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-800 uppercase tracking-wider">
              Доли трафика: Факт vs Цель (%)
            </span>
            <span className="text-[11px] text-slate-500">
              Сравнение целевых traffic_percentage
            </span>
          </div>

          <div className="h-56 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={distData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                <XAxis dataKey="provider" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} domain={[0, 100]} />
                <Tooltip
                  formatter={(value: any) => [`${value}%`]}
                  contentStyle={{ fontSize: '12px', borderRadius: '8px' }}
                />
                <Legend wrapperStyle={{ fontSize: '11px', paddingTop: '8px' }} />
                <Bar dataKey="actual" name="Фактическая доля" fill="#4f46e5" radius={[4, 4, 0, 0]} />
                <Bar dataKey="target" name="Целевая доля" fill="#94a3b8" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>

          {/* Deviation Table */}
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="border-b border-slate-100 text-slate-400 font-semibold">
                  <th className="py-1.5 px-2">Провайдер</th>
                  <th className="py-1.5 px-2">Заявок</th>
                  <th className="py-1.5 px-2">Факт %</th>
                  <th className="py-1.5 px-2">Цель %</th>
                  <th className="py-1.5 px-2">Отклонение</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {Object.entries(report.distribution || {}).map(([pId, stats]) => {
                  const diff = safeSub(stats.share_pct, stats.target_pct);
                  return (
                    <tr key={pId} className="hover:bg-slate-50/50">
                      <td className="py-1.5 px-2 font-bold uppercase text-slate-800">{pId}</td>
                      <td className="py-1.5 px-2 text-slate-700">{stats.count}</td>
                      <td className="py-1.5 px-2 font-semibold text-slate-900">{formatPercent(stats.share_pct)}</td>
                      <td className="py-1.5 px-2 text-slate-500">{formatPercent(stats.target_pct)}</td>
                      <td className="py-1.5 px-2">
                        <span
                          className={`font-semibold ${
                            Math.abs(diff) < 5
                              ? 'text-emerald-600'
                              : diff > 0
                              ? 'text-blue-600'
                              : 'text-amber-600'
                          }`}
                        >
                          {formatPercent(diff, 1, { showSign: true })}
                        </span>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>

        {/* Projected Daily Utilization */}
        <div className="bg-white rounded-xl border border-slate-200 p-4 shadow-xs space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-800 uppercase tracking-wider">
              Projected Daily Utilization (Утилизация лимитов)
            </span>
            <span className="text-[11px] text-slate-500">
              Порог риска: &gt;80%
            </span>
          </div>

          <div className="space-y-3 pt-1">
            {Object.entries(report.projected_daily_utilization || {}).map(([pId, util]) => {
              const isHigh = util.utilization_pct >= 80;
              const isMedium = util.utilization_pct >= 60;

              return (
                <div key={pId} className="space-y-1.5 p-2.5 rounded-lg border border-slate-100 bg-slate-50/50">
                  <div className="flex justify-between items-center text-xs">
                    <span className="font-bold text-slate-900 uppercase">{pId}</span>
                    <span
                      className={`font-semibold px-2 py-0.5 rounded text-[11px] ${
                        isHigh
                          ? 'bg-rose-100 text-rose-800'
                          : isMedium
                          ? 'bg-amber-100 text-amber-800'
                          : 'bg-emerald-100 text-emerald-800'
                      }`}
                    >
                      {formatPercent(util.utilization_pct)} утилизировано
                    </span>
                  </div>

                  <div className="w-full h-2 bg-slate-200 rounded-full overflow-hidden">
                    <div
                      className={`h-full rounded-full transition-all ${
                        isHigh ? 'bg-rose-500' : isMedium ? 'bg-amber-500' : 'bg-indigo-600'
                      }`}
                      style={{ width: `${Math.min(util.utilization_pct, 100)}%` }}
                    />
                  </div>

                  <div className="flex justify-between text-[11px] text-slate-500 font-mono">
                    <span>Использовано: {formatCurrency(util.used)}</span>
                    <span>Лимит: {formatCurrency(util.limit)}</span>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Skip Reasons Breakdown */}
          <div className="pt-2 border-t border-slate-100">
            <span className="text-xs font-bold text-slate-800 uppercase tracking-wider block mb-2">
              Причины пропусков (Skip Reasons):
            </span>
            <div className="space-y-1.5">
              {skipData.map((s, idx) => (
                <div key={idx} className="flex justify-between items-center text-xs bg-slate-50 px-2.5 py-1.5 rounded border border-slate-100">
                  <span className="text-slate-700 font-medium">{s.reason}</span>
                  <span className="font-bold text-slate-900 font-mono bg-white px-2 py-0.5 rounded border border-slate-200">
                    {s.count} раз
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Smart Recommendations Section */}
      <div className="bg-gradient-to-br from-indigo-50/60 to-white rounded-xl border border-indigo-200 p-4 shadow-xs space-y-3">
        <div className="flex items-center gap-2">
          <Lightbulb className="w-4 h-4 text-indigo-600" />
          <h3 className="text-sm font-bold text-indigo-950">
            Рекомендации по оптимизации роутинга (Routing Report Insights)
          </h3>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-2.5">
          {Array.isArray(report.recommendations) && report.recommendations.length > 0 ? (
            report.recommendations.map((rec, idx) => (
              <div
                key={idx}
                className="p-3 bg-white rounded-lg border border-indigo-100 shadow-xs flex items-start gap-2.5 text-xs text-slate-800"
              >
                <div className="mt-0.5 p-1 rounded-full bg-indigo-100 text-indigo-700 shrink-0">
                  <AlertCircle className="w-3.5 h-3.5" />
                </div>
                <div>
                  <span className="font-semibold text-slate-900 block mb-0.5">Рекомендация #{idx + 1}</span>
                  <p className="text-slate-600 leading-relaxed">{rec}</p>
                </div>
              </div>
            ))
          ) : (
            <div className="text-xs text-slate-500">Рекомендации сформируются после симуляции очереди</div>
          )}
        </div>
      </div>
    </section>
  );
}
