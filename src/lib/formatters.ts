import Big from 'big.js';

// Configure high precision for divisions and internal calculations
Big.DP = 20;

export { Big };

export interface CurrencyFormatOptions {
  currency?: string;
  maxFractionDigits?: number;
  showSign?: boolean;
}

/**
 * Safely converts any numeric, string, or Big value into a Big instance.
 * Handles commas, whitespace, and scientific notation without throwing errors.
 */
export function toBig(val: number | string | Big | null | undefined): Big {
  if (val instanceof Big) return val;
  if (val === null || val === undefined || val === '') return new Big(0);
  try {
    const cleanStr = String(val).trim().replace(',', '.');
    return new Big(cleanStr);
  } catch {
    return new Big(0);
  }
}

/**
 * Formats monetary and crypto values with high-precision arithmetic using Big.js.
 * - Micro-amounts & crypto fractions (e.g. 0.0001, 0.00000001) are preserved with exact decimals without IEEE 754 precision loss.
 * - Standard currency amounts (e.g. 100 000 ₽, 5 000 000 ₽) are formatted with clear thousand delimiters and optional fractions.
 */
export function formatCurrency(
  amount: number | string | Big | null | undefined,
  options: CurrencyFormatOptions = {}
): string {
  const currencySymbol = options.currency !== undefined ? options.currency : '₽';
  const maxDecimals = options.maxFractionDigits !== undefined ? options.maxFractionDigits : 8;

  try {
    const b = toBig(amount);
    if (b.eq(0)) {
      return currencySymbol ? `0 ${currencySymbol}` : '0';
    }

    const absB = b.abs();
    const isNegative = b.lt(0);
    const sign = isNegative ? '-' : (options.showSign ? '+' : '');

    // Case 1: Micro-amounts and crypto fractions (< 1, e.g. 0.0001, 0.00000001)
    if (absB.lt(1)) {
      const formattedNum = absB.toFixed(maxDecimals).replace(/\.?0+$/, '');
      return currencySymbol ? `${sign}${formattedNum} ${currencySymbol}` : `${sign}${formattedNum}`;
    }

    // Case 2: Greater or equal to 1
    const intPart = absB.round(0, 0); // 0 = roundDown in Big.js
    const fracPart = absB.minus(intPart);
    const intStr = intPart.toFixed(0).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');

    if (fracPart.eq(0)) {
      return currencySymbol ? `${sign}${intStr} ${currencySymbol}` : `${sign}${intStr}`;
    }

    // Fractional part exists for values >= 1 (e.g. 25000.5)
    const decimalsToKeep = Math.min(maxDecimals, 4);
    const fullRounded = absB.toFixed(decimalsToKeep).replace(/\.?0+$/, '');
    const fracStr = fullRounded.split('.')[1];

    if (!fracStr) {
      return currencySymbol ? `${sign}${intStr} ${currencySymbol}` : `${sign}${intStr}`;
    }

    const formattedWithFrac = `${sign}${intStr},${fracStr}`;
    return currencySymbol ? `${formattedWithFrac} ${currencySymbol}` : formattedWithFrac;
  } catch {
    return currencySymbol ? `${amount} ${currencySymbol}` : String(amount);
  }
}

/**
 * High-precision percentage formatter using Big.js to prevent IEEE-754 float glitches.
 */
export function formatPercent(
  value: number | string | Big | null | undefined,
  decimals: number = 1,
  options: { showSign?: boolean } = {}
): string {
  try {
    const b = toBig(value);
    const sign = options.showSign && b.gt(0) ? '+' : '';
    return `${sign}${b.toFixed(decimals)}%`;
  } catch {
    return `${value}%`;
  }
}

/**
 * High-precision crypto amount formatter with custom asset ticker (e.g., 'BTC', 'USDT').
 */
export function formatCryptoAmount(
  amount: number | string | Big | null | undefined,
  symbol: string = 'USDT',
  decimals: number = 8
): string {
  return formatCurrency(amount, {
    currency: symbol,
    maxFractionDigits: decimals
  });
}

/**
 * Safe high-precision addition: a + b
 */
export function safeAdd(
  a: number | string | Big | null | undefined,
  b: number | string | Big | null | undefined
): number {
  return parseFloat(toBig(a).plus(toBig(b)).toFixed(8));
}

/**
 * Safe high-precision subtraction: a - b
 */
export function safeSub(
  a: number | string | Big | null | undefined,
  b: number | string | Big | null | undefined
): number {
  return parseFloat(toBig(a).minus(toBig(b)).toFixed(8));
}

/**
 * Safe high-precision multiplication: a * b
 */
export function safeMul(
  a: number | string | Big | null | undefined,
  b: number | string | Big | null | undefined
): number {
  return parseFloat(toBig(a).times(toBig(b)).toFixed(8));
}

/**
 * Safe high-precision division: a / b
 */
export function safeDiv(
  a: number | string | Big | null | undefined,
  b: number | string | Big | null | undefined
): number {
  const bBig = toBig(b);
  if (bBig.eq(0)) return 0;
  return parseFloat(toBig(a).div(bBig).toFixed(8));
}

/**
 * Safe high-precision array summation
 */
export function safeSum(items: (number | string | Big | null | undefined)[]): number {
  return items.reduce<number>((acc, item) => safeAdd(acc, item), 0);
}

/**
 * Calculates deficit between target and actual value safely: max(0, target - actual)
 */
export function calcDeficit(
  target: number | string | Big | null | undefined,
  actual: number | string | Big | null | undefined
): number {
  const diff = safeSub(target, actual);
  return diff > 0 ? diff : 0;
}

export const REASON_TRANSLATIONS: Record<string, { label: string; desc: string; color: string }> = {
  amount_exceeds_limit: {
    label: 'Сумма превышает максимум',
    desc: 'Сумма заявки выше максимального чека провайдера',
    color: 'text-amber-700 bg-amber-50 border-amber-200'
  },
  amount_below_min: {
    label: 'Сумма ниже минимума',
    desc: 'Сумма заявки ниже порога минимального чека',
    color: 'text-amber-700 bg-amber-50 border-amber-200'
  },
  bank_not_in_list: {
    label: 'Банк не поддерживается',
    desc: 'Банк получателя отсутствует в списке доступных',
    color: 'text-rose-700 bg-rose-50 border-rose-200'
  },
  bank_excluded: {
    label: 'Банк в черном списке',
    desc: 'Банк находится в списке исключений exclude_banks',
    color: 'text-rose-700 bg-rose-50 border-rose-200'
  },
  daily_limit_exceeded: {
    label: 'Превышен суточный лимит',
    desc: 'Сумма операции превысит допустимый суточный оборот',
    color: 'text-purple-700 bg-purple-50 border-purple-200'
  },
  in_progress_count_limit_reached: {
    label: 'Лимит заявок in-progress',
    desc: 'Достигнут максимум одновременных транзакций',
    color: 'text-orange-700 bg-orange-50 border-orange-200'
  },
  in_progress_amount_limit_reached: {
    label: 'Лимит объема in-progress',
    desc: 'Превышен суммарный объем зависших средств',
    color: 'text-orange-700 bg-orange-50 border-orange-200'
  },
  margin_agreement_negative: {
    label: 'Отрицательная маржа',
    desc: 'Комиссия партнера выше тарифа мерчанта',
    color: 'text-red-700 bg-red-50 border-red-200'
  },
  no_available_requisites: {
    label: 'Нет свободных реквизитов',
    desc: 'Терминалы провайдера временно исчерпаны',
    color: 'text-slate-700 bg-slate-100 border-slate-200'
  },
  rate_limit_exceeded: {
    label: 'Превышен RPM лимит',
    desc: 'Превышена интенсивность запросов в минуту',
    color: 'text-orange-700 bg-orange-50 border-orange-200'
  },
  simulated_expired: {
    label: 'Таймаут шлюза',
    desc: 'Провайдер не ответил вовремя, каскадный переход',
    color: 'text-amber-700 bg-amber-50 border-amber-200'
  },
  simulated_rejected: {
    label: 'Отказ шлюза',
    desc: 'Провайдер отклонил операцию, переход к следующему',
    color: 'text-red-700 bg-red-50 border-red-200'
  },
  only_eligible_provider: {
    label: 'Единственный подходящий',
    desc: 'Только данный партнер удовлетворяет всем Hard-constraints',
    color: 'text-emerald-700 bg-emerald-50 border-emerald-200'
  },
  traffic_share_catch_up: {
    label: 'Балансировка доли (Count)',
    desc: 'Провайдер отстает от целевой доли по количеству заявок',
    color: 'text-blue-700 bg-blue-50 border-blue-200'
  },
  volume_share_deficit: {
    label: 'Балансировка оборота (Volume)',
    desc: 'Провайдер отстает от целевой доли денежного объема',
    color: 'text-blue-700 bg-blue-50 border-blue-200'
  },
  daily_turnover_min_deficit: {
    label: 'Фин. обязательство',
    desc: 'Приоритет для выполнения гарантированного суточного минимума',
    color: 'text-indigo-700 bg-indigo-50 border-indigo-200'
  },
  cascade_priority: {
    label: 'Приоритет в каскаде',
    desc: 'Выбор по наивысшему рангу очереди',
    color: 'text-emerald-700 bg-emerald-50 border-emerald-200'
  },
  optimal_amount_tier: {
    label: 'Оптимальный чек',
    desc: 'Попадание в целевой диапазон сумм провайдера',
    color: 'text-emerald-700 bg-emerald-50 border-emerald-200'
  },
  highest_composite_score: {
    label: 'Максимальный скоринг',
    desc: 'Наилучший баланс конверсии, маржи, лимитов и долей',
    color: 'text-emerald-700 bg-emerald-50 border-emerald-200'
  },
  fallback_all_providers_ineligible: {
    label: 'Fallback (SpacePayments)',
    desc: 'Все внешние партнеры отсеяны Hard-constraints',
    color: 'text-violet-700 bg-violet-50 border-violet-200'
  },
  fallback_after_eligible_failure: {
    label: 'Fallback после сбоя',
    desc: 'Единственный кандидат отказал в обработке',
    color: 'text-violet-700 bg-violet-50 border-violet-200'
  }
};

export const BANK_LABELS: Record<string, { name: string; color: string }> = {
  sber: { name: 'Сбербанк', color: 'bg-emerald-100 text-emerald-800' },
  tbank: { name: 'Т-Банк', color: 'bg-yellow-100 text-yellow-800' },
  vtb: { name: 'ВТБ', color: 'bg-blue-100 text-blue-800' },
  alfa: { name: 'Альфа-Банк', color: 'bg-red-100 text-red-800' },
  raiffeisen: { name: 'Райффайзен', color: 'bg-amber-100 text-amber-900' },
  gazprombank: { name: 'Газпромбанк', color: 'bg-indigo-100 text-indigo-800' },
  ozon: { name: 'Озон Банк', color: 'bg-cyan-100 text-cyan-800' },
  yoo_money: { name: 'ЮMoney', color: 'bg-purple-100 text-purple-800' },
  sbp: { name: 'СБП', color: 'bg-teal-100 text-teal-800' }
};

import type { ProvidersMap, Provider } from '../types';

export function normalizeProvidersMap(raw: any): ProvidersMap {
  if (!raw || typeof raw !== 'object') return {};

  const map: ProvidersMap = {};
  let list: any[] = [];

  if (Array.isArray(raw)) {
    list = raw;
  } else if (raw.providers && Array.isArray(raw.providers)) {
    list = raw.providers;
  } else {
    list = Object.entries(raw)
      .filter(([key, val]) => val && typeof val === 'object' && !['snapshot_at', 'gateway', 'merchant'].includes(key))
      .map(([key, val]: any) => ({ ...val, payment_system: val.payment_system || key }));
  }

  list.forEach((p: any) => {
    if (!p || typeof p !== 'object') return;
    const id = (p.payment_system || p.id || p.name || '').toString().toLowerCase();
    if (!id) return;

    map[id] = {
      name: p.name || (p.payment_system ? p.payment_system.toUpperCase() : id.toUpperCase()),
      status: p.status === 'inactive' || p.status === 'maintenance' ? p.status : 'active',
      traffic_percentage: Number(p.traffic_percentage) || 0,
      volume_share_pct: Number(p.volume_share_pct ?? p.traffic_percentage) || 0,
      priority: Number(p.priority) || 1,
      limit_amount_min: p.limit_amount_min != null ? Number(p.limit_amount_min) : 0,
      limit_amount_max: p.limit_amount_max != null ? Number(p.limit_amount_max) : 1000000000,
      daily_amount_limit: p.daily_amount_limit != null ? Number(p.daily_amount_limit) : 0,
      daily_approved_amount: Number(p.daily_approved_amount) || 0,
      in_progress_count_limit: p.in_progress_count_limit != null ? Number(p.in_progress_count_limit) : 0,
      in_progress_count: Number(p.in_progress_count) || 0,
      in_progress_amount_limit: p.in_progress_amount_limit != null ? Number(p.in_progress_amount_limit) : 0,
      in_progress_amount: Number(p.in_progress_amount) || 0,
      available_requisites: Number(p.available_requisites) || 0,
      banks: Array.isArray(p.banks) ? p.banks : [],
      exclude_banks: Array.isArray(p.exclude_banks) ? p.exclude_banks : [],
      conversion_24h: Number(p.conversion_24h) || 0,
      provider_margin_pct: Number(p.provider_margin_pct) || 0,
      merchant_margin_pct: Number(p.merchant_margin_pct) || 0,
      requests_per_minute_limit: Number(p.requests_per_minute_limit) || 60,
      daily_turnover_min: Number(p.daily_turnover_min) || 0,
      daily_turnover_max: Number(p.daily_turnover_max) || 0,
      avg_latency_sec: Number(p.avg_latency_sec) || 0,
      allow_negative_agreement: Boolean(p.allow_negative_agreement),
      is_fallback: Boolean(p.is_fallback || p.traffic_percentage === 0 || id === 'spacepayments')
    };
  });

  return map;
}

