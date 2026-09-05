import { useState } from 'react';
import { Operation, RoutingDecision } from '../types';
import { formatCurrency, REASON_TRANSLATIONS, BANK_LABELS } from '../lib/formatters';
import { ArrowRight, CheckCircle2, XCircle, Clock, AlertTriangle, ChevronDown, ChevronUp, Sparkles, Filter } from 'lucide-react';

interface OperationsWaterfallProps {
  operations: Operation[];
  decisions: RoutingDecision[];
  onSelectOperation?: (op: Operation) => void;
}

export function OperationsWaterfall({ operations, decisions }: OperationsWaterfallProps) {
  const [expandedOpId, setExpandedOpId] = useState<string | null>(operations[0]?.operation_id || null);
  const [filterProvider, setFilterProvider] = useState<string>('all');

  const decisionsMap = new Map<string, RoutingDecision>();
  decisions.forEach((d) => decisionsMap.set(d.operation_id, d));

  const filteredOperations = operations.filter((op) => {
    if (filterProvider === 'all') return true;
    const dec = decisionsMap.get(op.operation_id);
    return dec?.selected_provider === filterProvider;
  });

  return (
    <section className="bg-white rounded-xl border border-slate-200 p-4 shadow-xs space-y-4">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100">
        <div>
          <div className="flex items-center gap-2">
            <h2 className="text-sm font-bold text-slate-900">Очередь выплат и Waterfall-решения роутера</h2>
            <span className="px-2 py-0.5 text-xs font-semibold bg-indigo-50 text-indigo-700 rounded-full">
              {filteredOperations.length} из {operations.length}
            </span>
          </div>
          <p className="text-xs text-slate-500 mt-0.5">
            Пошаговая история рассмотрения шлюзов, причины исключений и итоговый выбор
          </p>
        </div>

        <div className="flex items-center gap-2">
          <Filter className="w-3.5 h-3.5 text-slate-400" />
          <span className="text-xs text-slate-500">Фильтр по партнеру:</span>
          <select
            value={filterProvider}
            onChange={(e) => setFilterProvider(e.target.value)}
            className="text-xs border border-slate-200 rounded-lg px-2 py-1 bg-white text-slate-700 focus:outline-hidden focus:ring-1 focus:ring-indigo-500"
          >
            <option value="all">Все партнеры</option>
            <option value="vipay">ViPay</option>
            <option value="payflow">PayFlow</option>
            <option value="quickpay">QuickPay</option>
            <option value="spacepayments">SpacePayments (Fallback)</option>
          </select>
        </div>
      </div>

      <div className="space-y-2.5">
        {filteredOperations.map((op) => {
          const dec = decisionsMap.get(op.operation_id);
          const isExpanded = expandedOpId === op.operation_id;
          const bankInfo = BANK_LABELS[op.bank] || { name: op.bank, color: 'bg-slate-100 text-slate-700' };

          return (
            <div
              key={op.operation_id}
              id={`operation-item-${op.operation_id}`}
              className={`border rounded-xl transition-all overflow-hidden ${
                isExpanded
                  ? 'border-indigo-300 ring-1 ring-indigo-200 bg-slate-50/40'
                  : 'border-slate-200 bg-white hover:border-slate-300'
              }`}
            >
              {/* Header row */}
              <div
                onClick={() => setExpandedOpId(isExpanded ? null : op.operation_id)}
                className="p-3.5 cursor-pointer flex flex-col md:flex-row md:items-center justify-between gap-3"
              >
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-lg bg-slate-100 flex items-center justify-center font-mono text-xs font-bold text-slate-700 shrink-0">
                    {op.operation_id.replace('op_', '#')}
                  </div>

                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-bold text-slate-900 text-sm">
                        {formatCurrency(op.amount)}
                      </span>
                      <span className={`text-[11px] px-2 py-0.5 rounded-md font-medium ${bankInfo.color}`}>
                        {bankInfo.name}
                      </span>
                      {op.client_id && (
                        <span className="text-[11px] font-mono text-slate-400 hidden sm:inline">
                          {op.client_id}
                        </span>
                      )}
                    </div>
                    <span className="text-[11px] text-slate-400 font-mono">
                      ID: {op.operation_id}
                    </span>
                  </div>
                </div>

                <div className="flex items-center gap-3">
                  {dec ? (
                    <>
                      <div className="text-right">
                        <div className="flex items-center gap-1.5 justify-end">
                          <span className="text-xs text-slate-500">Выбран:</span>
                          <span className="text-xs font-bold text-slate-900 bg-indigo-50 border border-indigo-200 text-indigo-800 px-2 py-0.5 rounded-md">
                            {dec.selected_provider}
                          </span>
                        </div>
                        <div className="flex items-center gap-1 justify-end text-[11px] mt-0.5">
                          {dec.simulated_result === 'approved' ? (
                            <span className="text-emerald-600 font-medium inline-flex items-center gap-0.5">
                              <CheckCircle2 className="w-3 h-3" /> Успешно ({dec.latency_sec}с)
                            </span>
                          ) : (
                            <span className="text-rose-600 font-medium inline-flex items-center gap-0.5">
                              <XCircle className="w-3 h-3" /> {dec.simulated_result} ({dec.latency_sec}с)
                            </span>
                          )}
                        </div>
                      </div>
                    </>
                  ) : (
                    <span className="text-xs text-slate-400">Ожидает роутинга</span>
                  )}

                  <div className="p-1 rounded text-slate-400 hover:text-slate-600">
                    {isExpanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                  </div>
                </div>
              </div>

              {/* Waterfall Attempts Section */}
              {isExpanded && dec && (
                <div className="border-t border-slate-200 p-4 bg-white space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-slate-800 uppercase tracking-wider flex items-center gap-1.5">
                      <Sparkles className="w-3.5 h-3.5 text-indigo-600" />
                      Последовательность попыток роутера ({dec.attempts.length}):
                    </span>
                    <span className="text-xs text-slate-500 font-mono">
                      Итог: {dec.simulated_result} • {dec.latency_sec} сек
                    </span>
                  </div>

                  <div className="space-y-2">
                    {dec.attempts.map((att, idx) => {
                      const isSelected = att.decision === 'selected';
                      const reasonMeta = REASON_TRANSLATIONS[att.reason] || {
                        label: att.reason,
                        desc: att.details || '',
                        color: isSelected ? 'text-emerald-700 bg-emerald-50 border-emerald-200' : 'text-slate-700 bg-slate-50 border-slate-200'
                      };

                      return (
                        <div
                          key={idx}
                          className={`p-3 rounded-lg border text-xs flex flex-col sm:flex-row sm:items-center justify-between gap-2.5 transition-all ${
                            isSelected
                              ? 'bg-emerald-50/70 border-emerald-300 ring-1 ring-emerald-200'
                              : 'bg-slate-50 border-slate-200'
                          }`}
                        >
                          <div className="flex items-start gap-2.5">
                            <div className="mt-0.5">
                              {isSelected ? (
                                <div className="w-5 h-5 rounded-full bg-emerald-600 text-white flex items-center justify-center font-bold text-[10px]">
                                  ✓
                                </div>
                              ) : (
                                <div className="w-5 h-5 rounded-full bg-slate-200 text-slate-600 flex items-center justify-center font-bold text-[10px]">
                                  {idx + 1}
                                </div>
                              )}
                            </div>

                            <div>
                              <div className="flex items-center gap-2">
                                <span className="font-bold text-slate-900 uppercase">
                                  {att.provider}
                                </span>
                                <span
                                  className={`text-[10px] px-1.5 py-0.5 rounded font-bold border ${
                                    isSelected
                                      ? 'bg-emerald-100 text-emerald-800 border-emerald-300'
                                      : 'bg-slate-200 text-slate-700 border-slate-300'
                                  }`}
                                >
                                  {isSelected ? 'SELECTED' : 'SKIPPED'}
                                </span>
                              </div>

                              <div className="mt-1">
                                <span className="font-semibold text-slate-800">
                                  {reasonMeta.label}
                                </span>
                                {att.details && (
                                  <p className="text-slate-600 text-[11px] font-mono mt-0.5">
                                    {att.details}
                                  </p>
                                )}
                              </div>
                            </div>
                          </div>

                          <div className="self-end sm:self-center">
                            {isSelected ? (
                              <span className="inline-flex items-center gap-1 text-emerald-700 font-semibold text-[11px] bg-white px-2 py-1 rounded border border-emerald-200">
                                <CheckCircle2 className="w-3.5 h-3.5" />
                                Назначена выплата
                              </span>
                            ) : (
                              <span className="inline-flex items-center gap-1 text-slate-500 text-[11px] bg-white px-2 py-1 rounded border border-slate-200">
                                <XCircle className="w-3.5 h-3.5 text-rose-400" />
                                Исключен
                              </span>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </section>
  );
}
