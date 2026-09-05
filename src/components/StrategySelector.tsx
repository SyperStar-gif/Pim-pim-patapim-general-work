import { RoutingStrategy, StrategyOption } from '../types';
import { Sliders, Layers, Percent, TrendingUp, DollarSign, Zap, Scale } from 'lucide-react';

const STRATEGIES: StrategyOption[] = [
  {
    id: 'combined',
    number: 0,
    name: 'Сбалансированная (Composite)',
    criterion: 'Взвешенный мультифакторный скоринг',
    description: 'Комплексный учет всех soft-целей: долей, обязательств, чеков, конверсии и утилизации лимитов.',
    example: 'Автоматическое разрешение конфликтов с максимальной эффективностью'
  },
  {
    id: 'traffic_share',
    number: 1,
    name: 'Доля по числу заявок',
    criterion: 'Целевой % от общего count операций',
    description: 'Если провайдер получает меньше целевой доли, его приоритет повышается, иначе понижается.',
    example: 'vipay 40%, payflow 35%, quickpay 25%'
  },
  {
    id: 'volume_share',
    number: 2,
    name: 'Доля по объёму выплат',
    criterion: 'Целевой % от денежного объема (₽)',
    description: 'Распределение по сумме переведенных рублей, а не по количеству заявок.',
    example: 'vipay 50% оборота, остальные 50%'
  },
  {
    id: 'cascade_priority',
    number: 3,
    name: 'Очередь в каскаде',
    criterion: 'Последовательный обход по priority',
    description: 'Строгая очередность партнеров: попытка на vipay, при отказе payflow, затем quickpay.',
    example: 'vipay (1) → payflow (2) → quickpay (3) → fallback'
  },
  {
    id: 'amount_tier',
    number: 4,
    name: 'По сумме чека',
    criterion: 'Диапазоны сумм заявок',
    description: 'Маршрутизация по специализированным тирам чеков для каждого партнера.',
    example: '500–50k → payflow; 50k–100k → vipay; >100k → quickpay'
  },
  {
    id: 'conversion_boost',
    number: 5,
    name: 'Приоритизация по конверсии',
    criterion: 'conversion_24h',
    description: 'Предпочитать провайдеров с максимальной подтвержденной суточной конверсией.',
    example: 'quickpay (96%) > vipay (94%) > payflow (89%)'
  },
  {
    id: 'rate_limit_intensity',
    number: 6,
    name: 'По интенсивности (RPM)',
    criterion: 'Rate limit на терминал/провайдера',
    description: 'Балансировка потока с учетом доступной пропускной способности (заявок/мин).',
    example: 'payflow (15/мин), vipay (20/мин), quickpay (25/мин)'
  },
  {
    id: 'financial_obligations',
    number: 7,
    name: 'По фин. обязательствам',
    criterion: 'Суточные обязательства (turnover min)',
    description: 'Принудительный приоритет партнерам, у которых еще не закрыт минимальный суточный порог.',
    example: 'payflow: гарантировать не менее 2 000 000 ₽/сутки'
  }
];

interface StrategySelectorProps {
  currentStrategy: RoutingStrategy;
  onSelectStrategy: (strategy: RoutingStrategy) => void;
}

export function StrategySelector({ currentStrategy, onSelectStrategy }: StrategySelectorProps) {
  const getIcon = (id: RoutingStrategy) => {
    switch (id) {
      case 'combined': return <Scale className="w-4 h-4 text-indigo-600" />;
      case 'traffic_share': return <Percent className="w-4 h-4 text-blue-600" />;
      case 'volume_share': return <DollarSign className="w-4 h-4 text-emerald-600" />;
      case 'cascade_priority': return <Layers className="w-4 h-4 text-amber-600" />;
      case 'amount_tier': return <Sliders className="w-4 h-4 text-purple-600" />;
      case 'conversion_boost': return <TrendingUp className="w-4 h-4 text-rose-600" />;
      case 'rate_limit_intensity': return <Zap className="w-4 h-4 text-orange-600" />;
      case 'financial_obligations': return <DollarSign className="w-4 h-4 text-teal-600" />;
    }
  };

  const activeOption = STRATEGIES.find((s) => s.id === currentStrategy) || STRATEGIES[0];

  return (
    <section className="bg-white rounded-xl border border-slate-200 p-4 shadow-xs">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pb-3 mb-3 border-b border-slate-100">
        <div className="flex items-center gap-2">
          <Scale className="w-4 h-4 text-indigo-600" />
          <h2 className="text-sm font-bold text-slate-900">Стратегия распределения выплат</h2>
          <span className="text-xs text-slate-500">
            (8 поддерживаемых режимов)
          </span>
        </div>
        <div className="text-xs font-medium text-indigo-700 bg-indigo-50 px-2.5 py-1 rounded-md border border-indigo-100 self-start sm:self-auto">
          Активная: <strong>{activeOption.name}</strong>
        </div>
      </div>

      <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-8 gap-2 mb-3">
        {STRATEGIES.map((st) => {
          const isActive = st.id === currentStrategy;
          return (
            <button
              key={st.id}
              id={`strategy-tab-${st.id}`}
              onClick={() => onSelectStrategy(st.id)}
              className={`flex flex-col items-start p-2.5 rounded-lg border text-left transition-all ${
                isActive
                  ? 'border-indigo-600 bg-indigo-50/50 shadow-xs ring-1 ring-indigo-600'
                  : 'border-slate-200 bg-white hover:bg-slate-50 text-slate-700'
              }`}
            >
              <div className="flex items-center justify-between w-full mb-1.5">
                <div className="p-1 rounded-md bg-white border border-slate-200 shadow-xs">
                  {getIcon(st.id)}
                </div>
                <span className="text-[10px] font-mono font-bold text-slate-600">
                  {st.number === 0 ? '★' : `#${st.number}`}
                </span>
              </div>
              <span className={`text-xs font-semibold leading-tight line-clamp-1 ${isActive ? 'text-indigo-950' : 'text-slate-800'}`}>
                {st.name}
              </span>
              <span className="text-[10px] text-slate-600 line-clamp-1 mt-0.5">
                {st.criterion}
              </span>
            </button>
          );
        })}
      </div>

      <div className="p-3 bg-slate-50 rounded-lg border border-slate-200 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs">
        <div className="space-y-0.5">
          <p className="font-semibold text-slate-800">
            Логика работы: <span className="font-normal text-slate-600">{activeOption.description}</span>
          </p>
          <p className="text-slate-500">
            <span className="font-medium text-slate-700">Пример настройки:</span> {activeOption.example}
          </p>
        </div>
        <div className="text-[11px] text-slate-500 whitespace-nowrap bg-white px-2.5 py-1.5 rounded-md border border-slate-200 self-start sm:self-auto">
          Hard-фильтры применяются <strong className="text-slate-800">до</strong> выбора стратегии
        </div>
      </div>
    </section>
  );
}
