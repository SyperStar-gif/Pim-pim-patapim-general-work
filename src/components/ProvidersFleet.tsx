import { useState } from 'react';
import { ProvidersMap, Provider } from '../types';
import { formatCurrency, formatPercent, BANK_LABELS, calcDeficit } from '../lib/formatters';
import { ShieldAlert, CheckCircle, Percent, Sliders, ArrowUpRight, Zap, Building2 } from 'lucide-react';

interface ProvidersFleetProps {
  providers: ProvidersMap;
  onUpdateProvider: (providerId: string, updated: Partial<Provider>) => void;
}

export function ProvidersFleet({ providers, onUpdateProvider }: ProvidersFleetProps) {
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editForm, setEditForm] = useState<Partial<Provider>>({});

  const startEdit = (id: string, p: Provider) => {
    setEditingId(id);
    setEditForm({
      traffic_percentage: p.traffic_percentage,
      volume_share_pct: p.volume_share_pct,
      priority: p.priority,
      limit_amount_min: p.limit_amount_min,
      limit_amount_max: p.limit_amount_max,
      daily_amount_limit: p.daily_amount_limit,
      requests_per_minute_limit: p.requests_per_minute_limit,
      daily_turnover_min: p.daily_turnover_min
    });
  };

  const saveEdit = (id: string) => {
    onUpdateProvider(id, editForm);
    setEditingId(null);
  };

  const validProviders = Object.entries(providers).filter(
    ([id, p]) => p && typeof p === 'object' && !['snapshot_at', 'gateway', 'merchant', 'providers'].includes(id)
  );

  return (
    <section className="space-y-3">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Building2 className="w-4 h-4 text-indigo-600" />
          <h2 className="text-sm font-bold text-slate-900">Платёжные партнеры и состояние шлюзов</h2>
          <span className="text-xs text-slate-500">
            ({validProviders.length} провайдера)
          </span>
        </div>
        <span className="text-xs text-slate-500">
          Данные из <code className="font-mono bg-slate-100 px-1 py-0.5 rounded text-slate-700">data/providers.json</code>
        </span>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-3.5">
        {validProviders.map(([id, p]) => {
          const utilPct = p.daily_amount_limit > 0 ? (p.daily_approved_amount / p.daily_amount_limit) * 100 : 0;
          const isFallback = p.is_fallback;
          const isEditing = editingId === id;
          const banks = Array.isArray(p.banks) ? p.banks : [];
          const excludeBanks = Array.isArray(p.exclude_banks) ? p.exclude_banks : [];

          return (
            <div
              key={id}
              id={`provider-card-${id}`}
              className={`rounded-xl border p-4 bg-white shadow-xs flex flex-col justify-between transition-all ${
                isFallback
                  ? 'border-violet-200 bg-violet-50/20'
                  : utilPct > 80
                  ? 'border-amber-300 ring-1 ring-amber-200'
                  : 'border-slate-200 hover:border-slate-300'
              }`}
            >
              <div>
                {/* Header */}
                <div className="flex items-start justify-between gap-2 pb-2.5 mb-2.5 border-b border-slate-100">
                  <div>
                    <div className="flex items-center gap-1.5">
                      <span className="font-bold text-slate-900 text-sm">{p.name}</span>
                      {isFallback ? (
                        <span className="px-1.5 py-0.5 text-[10px] font-bold bg-violet-100 text-violet-800 rounded border border-violet-200">
                          FALLBACK
                        </span>
                      ) : (
                        <span className="px-1.5 py-0.5 text-[10px] font-medium bg-slate-100 text-slate-600 rounded">
                          Приоритет #{p.priority}
                        </span>
                      )}
                    </div>
                    <div className="flex items-center gap-2 mt-0.5">
                      <span className="text-[11px] font-mono text-slate-500 uppercase">{id}</span>
                      <span className="inline-flex items-center gap-1 text-[11px] text-emerald-600">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                        {p.status}
                      </span>
                    </div>
                  </div>

                  <button
                    onClick={() => (isEditing ? setEditingId(null) : startEdit(id, p))}
                    className="p-1 rounded text-slate-600 hover:text-slate-600 hover:bg-slate-100 text-xs flex items-center gap-1"
                    title="Настроить параметры"
                  >
                    <Sliders className="w-3.5 h-3.5" />
                  </button>
                </div>

                {isEditing ? (
                  <div className="space-y-2 py-1 text-xs">
                    <div className="grid grid-cols-2 gap-2">
                      <div>
                        <label className="text-[10px] text-slate-500 block">Цель по Count %</label>
                        <input
                          type="number"
                          value={editForm.traffic_percentage || 0}
                          onChange={(e) => setEditForm({ ...editForm, traffic_percentage: parseFloat(e.target.value) || 0 })}
                          className="w-full px-2 py-1 border rounded text-xs"
                        />
                      </div>
                      <div>
                        <label className="text-[10px] text-slate-500 block">Цель по Volume %</label>
                        <input
                          type="number"
                          value={editForm.volume_share_pct || 0}
                          onChange={(e) => setEditForm({ ...editForm, volume_share_pct: parseFloat(e.target.value) || 0 })}
                          className="w-full px-2 py-1 border rounded text-xs"
                        />
                      </div>
                    </div>

                    <div className="grid grid-cols-2 gap-2">
                      <div>
                        <label className="text-[10px] text-slate-500 block">Чек Min (₽ / крипто)</label>
                        <input
                          type="number"
                          step="any"
                          value={editForm.limit_amount_min || 0}
                          onChange={(e) => setEditForm({ ...editForm, limit_amount_min: parseFloat(e.target.value) || 0 })}
                          className="w-full px-2 py-1 border rounded text-xs"
                        />
                      </div>
                      <div>
                        <label className="text-[10px] text-slate-500 block">Чек Max (₽ / крипто)</label>
                        <input
                          type="number"
                          step="any"
                          value={editForm.limit_amount_max || 0}
                          onChange={(e) => setEditForm({ ...editForm, limit_amount_max: parseFloat(e.target.value) || 0 })}
                          className="w-full px-2 py-1 border rounded text-xs"
                        />
                      </div>
                    </div>

                    <div>
                      <label className="text-[10px] text-slate-500 block">Дневной лимит (₽ / крипто)</label>
                      <input
                        type="number"
                        step="any"
                        value={editForm.daily_amount_limit || 0}
                        onChange={(e) => setEditForm({ ...editForm, daily_amount_limit: parseFloat(e.target.value) || 0 })}
                        className="w-full px-2 py-1 border rounded text-xs"
                      />
                    </div>

                    <div className="flex gap-2 pt-2">
                      <button
                        onClick={() => saveEdit(id)}
                        className="flex-1 py-1 px-2 bg-indigo-600 text-white rounded text-xs font-semibold hover:bg-indigo-700"
                      >
                        Применить
                      </button>
                      <button
                        onClick={() => setEditingId(null)}
                        className="py-1 px-2 border rounded text-xs text-slate-600 hover:bg-slate-100"
                      >
                        Отмена
                      </button>
                    </div>
                  </div>
                ) : (
                  <>
                    {/* Target Shares */}
                    {!isFallback && (
                      <div className="grid grid-cols-2 gap-2 mb-3 bg-slate-50 p-2 rounded-lg text-xs">
                        <div>
                          <span className="text-[10px] text-slate-600 block">Цель по заявкам</span>
                          <span className="font-bold text-slate-800">{formatPercent(p.traffic_percentage)}</span>
                        </div>
                        <div>
                          <span className="text-[10px] text-slate-600 block">Цель по объёму</span>
                          <span className="font-bold text-slate-800">{formatPercent(p.volume_share_pct)}</span>
                        </div>
                      </div>
                    )}

                    {/* Daily Turnover Bar */}
                    <div className="space-y-1 mb-3">
                      <div className="flex items-center justify-between text-[11px]">
                        <span className="text-slate-600">Дневной оборот:</span>
                        <span className="font-semibold text-slate-800">
                          {formatPercent(utilPct)}
                        </span>
                      </div>
                      <div className="w-full h-2 bg-slate-100 rounded-full overflow-hidden">
                        <div
                          className={`h-full rounded-full transition-all ${
                            utilPct > 85 ? 'bg-rose-500' : utilPct > 65 ? 'bg-amber-500' : 'bg-indigo-600'
                          }`}
                          style={{ width: `${Math.min(utilPct, 100)}%` }}
                        />
                      </div>
                      <div className="flex justify-between text-[10px] text-slate-600">
                        <span>{formatCurrency(p.daily_approved_amount)}</span>
                        <span>{formatCurrency(p.daily_amount_limit)}</span>
                      </div>
                    </div>

                    {/* Constraints summary */}
                    <div className="space-y-1.5 text-xs text-slate-600">
                      <div className="flex justify-between py-0.5 border-b border-slate-100">
                        <span className="text-slate-600">Диапазон чека:</span>
                        <span className="font-medium text-slate-800">
                          {formatCurrency(p.limit_amount_min)} – {formatCurrency(p.limit_amount_max)}
                        </span>
                      </div>

                      <div className="flex justify-between py-0.5 border-b border-slate-100">
                        <span className="text-slate-600">Конверсия 24ч:</span>
                        <span className="font-medium text-emerald-700">
                          {formatPercent(p.conversion_24h * 100)}
                        </span>
                      </div>

                      <div className="flex justify-between py-0.5 border-b border-slate-100">
                        <span className="text-slate-600">Маржа (Партнер / Мерчант):</span>
                        <span className={`font-medium ${p.provider_margin_pct > p.merchant_margin_pct && !p.allow_negative_agreement ? 'text-rose-600' : 'text-slate-800'}`}>
                          {p.provider_margin_pct}% / {p.merchant_margin_pct}%
                        </span>
                      </div>

                      <div className="flex justify-between py-0.5 border-b border-slate-100">
                        <span className="text-slate-600">In-progress / Реквизиты:</span>
                        <span className="font-medium text-slate-800">
                          {p.in_progress_count}/{p.in_progress_count_limit} заdemo | {p.available_requisites} рекв.
                        </span>
                      </div>

                      <div className="flex justify-between py-0.5">
                        <span className="text-slate-600">Интенсивность (RPM):</span>
                        <span className="font-medium text-slate-800">
                          {p.current_requests_this_minute || 0} / {p.requests_per_minute_limit} в мин.
                        </span>
                      </div>

                      {p.daily_turnover_min > 0 && (
                        <div className="mt-2 p-1.5 bg-indigo-50/50 rounded border border-indigo-100 text-[11px] text-indigo-900">
                          Обязательство: не менее {formatCurrency(p.daily_turnover_min)}/сут.
                          {p.daily_approved_amount < p.daily_turnover_min && (
                            <span className="text-rose-600 font-semibold block text-[10px]">
                              (Дефицит: {formatCurrency(calcDeficit(p.daily_turnover_min, p.daily_approved_amount))})
                            </span>
                          )}
                        </div>
                      )}
                    </div>

                    {/* Bank tags */}
                    <div className="mt-3 pt-2.5 border-t border-slate-100">
                      <span className="text-[10px] text-slate-600 block mb-1 font-medium">Банки:</span>
                      <div className="flex flex-wrap gap-1">
                        {banks.length === 0 ? (
                          <span className="text-[10px] text-slate-500 italic">Все доступные банки</span>
                        ) : (
                          banks.map((b) => (
                            <span
                              key={b}
                              className={`text-[9px] px-1.5 py-0.5 rounded font-medium ${
                                BANK_LABELS[b]?.color || 'bg-slate-100 text-slate-700'
                              }`}
                            >
                              {BANK_LABELS[b]?.name || b}
                            </span>
                          ))
                        )}
                        {excludeBanks.map((b) => (
                          <span
                            key={b}
                            className="text-[9px] px-1.5 py-0.5 rounded bg-rose-50 text-rose-700 border border-rose-200 line-through"
                            title="Исключенный банк"
                          >
                            {BANK_LABELS[b]?.name || b}
                          </span>
                        ))}
                      </div>
                    </div>
                  </>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
}
