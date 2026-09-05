export interface Provider {
  name: string;
  status: 'active' | 'inactive' | 'maintenance';
  traffic_percentage: number;
  volume_share_pct: number;
  priority: number;
  limit_amount_min: number;
  limit_amount_max: number;
  daily_amount_limit: number;
  daily_approved_amount: number;
  in_progress_count_limit: number;
  in_progress_count: number;
  in_progress_amount_limit: number;
  in_progress_amount: number;
  available_requisites: number;
  banks: string[];
  exclude_banks: string[];
  conversion_24h: number;
  provider_margin_pct: number;
  merchant_margin_pct: number;
  requests_per_minute_limit: number;
  current_requests_this_minute?: number;
  daily_turnover_min: number;
  daily_turnover_max: number;
  avg_latency_sec: number;
  allow_negative_agreement?: boolean;
  is_fallback?: boolean;
}

export type ProvidersMap = Record<string, Provider>;

export interface Operation {
  operation_id: string;
  amount: number;
  bank: string;
  client_id?: string;
  created_at?: string;
}

export interface RoutingAttempt {
  provider: string;
  decision: 'selected' | 'skipped';
  reason: string;
  details?: string;
}

export interface RoutingDecision {
  operation_id: string;
  selected_provider: string;
  attempts: RoutingAttempt[];
  simulated_result: 'approved' | 'rejected' | 'expired';
  latency_sec: number;
}

export interface ProviderDistribution {
  count: number;
  share_pct: number;
  target_pct: number;
}

export interface ProviderUtilization {
  used: number;
  limit: number;
  utilization_pct: number;
}

export interface RoutingReport {
  period: string;
  total_operations: number;
  distribution: Record<string, ProviderDistribution>;
  skip_reasons: Record<string, number>;
  projected_daily_utilization: Record<string, ProviderUtilization>;
  recommendations: string[];
}

export type RoutingStrategy =
  | 'combined'
  | 'traffic_share'
  | 'volume_share'
  | 'cascade_priority'
  | 'amount_tier'
  | 'conversion_boost'
  | 'rate_limit_intensity'
  | 'financial_obligations';

export interface StrategyOption {
  id: RoutingStrategy;
  number: number;
  name: string;
  criterion: string;
  description: string;
  example: string;
}
