import { useState } from 'react';
import { ProvidersMap } from '../types';
import { formatCurrency, formatPercent, BANK_LABELS, REASON_TRANSLATIONS, toBig, safeAdd } from '../lib/formatters';
import { Play, Sparkles, AlertCircle, CheckCircle2, XCircle, ArrowRight } from 'lucide-react';

interface SimulationSandboxProps {
  providers: ProvidersMap;
  onAddOperationToQueue: (op: { operation_id: string; amount: number; bank: string; client_id: string }) => void;
}

export function SimulationSandbox({ providers, onAddOperationToQueue }: SimulationSandboxProps) {
  const [amount, setAmount] = useState<number>(35000);
  const [bank, setBank] = useState<string>('sber');
  const [clientId, setClientId] = useState<string>('usr_demo');
  const [simulateResult, setSimulateResult] = useState<any | null>(null);

  // Client-side instant evaluation with high-precision Big.js arithmetic
  const runInstantSimulation = () => {
    const attempts: any[] = [];
    const eligible: any[] = [];
    const amountBig = toBig(amount);

    Object.entries(providers).forEach(([id, p]) => {
      if (!p || typeof p !== 'object' || ['snapshot_at', 'gateway', 'merchant', 'providers'].includes(id)) return;
      if (p.is_fallback) return;

      // 1. Status
      if (p.status !== 'active') {
        attempts.push({ id, eligible: false, reason: 'provider_not_active', details: `Статус: ${p.status}` });
        return;
      }
      // 2. Amount min
      if (amountBig.lt(toBig(p.limit_amount_min))) {
        attempts.push({
          id,
          eligible: false,
          reason: 'amount_below_min',
          details: `${formatCurrency(amount)} < ${formatCurrency(p.limit_amount_min)}`
        });
        return;
      }
      // 3. Amount max
      if (amountBig.gt(toBig(p.limit_amount_max))) {
        attempts.push({
          id,
          eligible: false,
          reason: 'amount_exceeds_limit',
          details: `${formatCurrency(amount)} > ${formatCurrency(p.limit_amount_max)}`
        });
        return;
      }
      // 4. Daily limit
      const projectedDaily = toBig(p.daily_approved_amount).plus(amountBig);
      if (projectedDaily.gt(toBig(p.daily_amount_limit))) {
        attempts.push({
          id,
          eligible: false,
          reason: 'daily_limit_exceeded',
          details: `${formatCurrency(projectedDaily)} > ${formatCurrency(p.daily_amount_limit)}`
        });
        return;
      }
      // 5. Bank excluded
      const excludeBanks = Array.isArray(p.exclude_banks) ? p.exclude_banks : [];
      if (excludeBanks.includes(bank)) {
        attempts.push({ id, eligible: false, reason: 'bank_excluded', details: `Банк '${bank}' в черном списке` });
        return;
      }
      // 6. Bank included
      const banks = Array.isArray(p.banks) ? p.banks : [];
      if (banks.length > 0 && !banks.includes(bank)) {
        attempts.push({ id, eligible: false, reason: 'bank_not_in_list', details: `Банк '${bank}' не поддерживается` });
        return;
      }
      // 7. Margin
      if (p.provider_margin_pct > p.merchant_margin_pct && !p.allow_negative_agreement) {
        attempts.push({ id, eligible: false, reason: 'margin_agreement_negative', details: `${p.provider_margin_pct}% > ${p.merchant_margin_pct}%` });
        return;
      }
      // 8. Requisites
      if (p.available_requisites <= 0) {
        attempts.push({ id, eligible: false, reason: 'no_available_requisites', details: '0 свободных реквизитов' });
        return;
      }

      // Passed!
      attempts.push({ id, eligible: true, score: p.traffic_percentage * 2 + (p.conversion_24h * 100) });
      eligible.push({ id, provider: p });
    });

    let selected = null;
    let selectedReason = '';

    if (eligible.length === 0) {
      selected = 'spacepayments';
      selectedReason = 'fallback_all_providers_ineligible';
    } else if (eligible.length === 1) {
      selected = eligible[0].id;
      selectedReason = 'only_eligible_provider';
    } else {
      // Pick highest score
      eligible.sort((a, b) => b.provider.priority - a.provider.priority);
      selected = eligible[0].id;
      selectedReason = 'optimal_candidate_by_strategy';
    }

    setSimulateResult({
      selected,
      selectedReason,
      attempts
    });
  };

  const handleAddToQueue = () => {
    const newId = `op_${Date.now().toString().slice(-4)}`;
    onAddOperationToQueue({
      operation_id: newId,
      amount,
      bank,
      client_id: clientId
    });
    setSimulateResult(null);
  };

  return (
    <section className="bg-white rounded-xl border border-slate-200 p-4 shadow-xs space-y-4">
      <div className="flex items-center justify-between pb-3 border-b border-slate-100">
        <div className="flex items-center gap-2">
          <Sparkles className="w-4 h-4 text-indigo-600" />
          <h2 className="text-sm font-bold text-slate-900">Интерактивный симулятор роутинга (Sandbox)</h2>
        </div>
        <span className="text-xs text-slate-500">
          Мгновенная проверка правил отсева и выбора партнера
        </span>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
        <div>
          <label className="text-xs font-semibold text-slate-700 block mb-1">Сумма выплаты (₽ / крипто)</label>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(Math.max(0.00000001, parseFloat(e.target.value) || 0))}
            className="w-full px-3 py-1.5 border border-slate-200 rounded-lg text-xs font-bold text-slate-900"
            step="any"
            min="0.00000001"
          />
          <div className="flex flex-wrap gap-1 mt-1">
            {[0.0001, 0.005, 500, 35000, 75000, 150000].map((v) => (
              <button
                key={v}
                onClick={() => setAmount(v)}
                className="text-[10px] px-1.5 py-0.5 bg-slate-100 hover:bg-slate-200 rounded text-slate-600 font-mono"
              >
                {v < 1 ? formatCurrency(v, { currency: '' }) : v >= 1000 ? `${v / 1000}k` : v}
              </button>
            ))}
          </div>
        </div>

        <div>
          <label className="text-xs font-semibold text-slate-700 block mb-1">Банк получателя</label>
          <select
            value={bank}
            onChange={(e) => setBank(e.target.value)}
            className="w-full px-3 py-1.5 border border-slate-200 rounded-lg text-xs font-medium text-slate-900 bg-white"
          >
            {Object.entries(BANK_LABELS).map(([bKey, bVal]) => (
              <option key={bKey} value={bKey}>
                {bVal.name} ({bKey})
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className="text-xs font-semibold text-slate-700 block mb-1">ID Клиента</label>
          <input
            type="text"
            value={clientId}
            onChange={(e) => setClientId(e.target.value)}
            className="w-full px-3 py-1.5 border border-slate-200 rounded-lg text-xs font-mono text-slate-800"
          />
        </div>

        <div className="flex flex-col justify-end gap-1.5">
          <button
            onClick={runInstantSimulation}
            className="w-full py-2 px-3 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-xs font-semibold flex items-center justify-center gap-1.5 transition-colors shadow-xs"
          >
            <Play className="w-3.5 h-3.5 fill-current" />
            Проверить маршрут
          </button>
          <button
            onClick={handleAddToQueue}
            className="w-full py-1.5 px-3 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg text-xs font-medium transition-colors"
          >
            + Добавить в очередь
          </button>
        </div>
      </div>

      {/* Simulation Result */}
      {simulateResult && (
        <div className="p-3 bg-slate-50 rounded-xl border border-slate-200 space-y-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="text-xs font-bold text-slate-900">Итоговый выбор:</span>
              <span className="text-xs font-bold text-indigo-900 bg-indigo-100 border border-indigo-200 px-2 py-0.5 rounded-md uppercase">
                {simulateResult.selected}
              </span>
              <span className="text-xs text-slate-600">
                ({REASON_TRANSLATIONS[simulateResult.selectedReason]?.label || simulateResult.selectedReason})
              </span>
            </div>
            <span className="text-xs text-slate-400">Сумма: {formatCurrency(amount)} • Банк: {bank}</span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
            {simulateResult.attempts.map((att: any) => (
              <div
                key={att.id}
                className={`p-2.5 rounded-lg border text-xs flex flex-col justify-between ${
                  att.eligible
                    ? 'bg-emerald-50 border-emerald-200 text-emerald-900'
                    : 'bg-rose-50 border-rose-200 text-rose-900'
                }`}
              >
                <div className="flex justify-between items-center mb-1">
                  <span className="font-bold uppercase">{att.id}</span>
                  <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded ${att.eligible ? 'bg-emerald-200 text-emerald-900' : 'bg-rose-200 text-rose-900'}`}>
                    {att.eligible ? 'ELIGIBLE' : 'SKIPPED'}
                  </span>
                </div>
                <div className="text-[11px]">
                  {att.eligible ? (
                    <span className="text-emerald-700 font-medium">Прошел все Hard-constraints</span>
                  ) : (
                    <div>
                      <span className="font-semibold text-rose-800">
                        {REASON_TRANSLATIONS[att.reason]?.label || att.reason}
                      </span>
                      <p className="font-mono text-[10px] text-rose-600 mt-0.5">{att.details}</p>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </section>
  );
}
