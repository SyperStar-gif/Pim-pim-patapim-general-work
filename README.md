# Smart Payment Router (Умный роутинг выплат)

Полнофункциональное решение для **Задачи 2: Умный роутинг выплат**.
Ядро системы разработано на **Ruby 3.1** с соблюдением всех ограничений (без сторонних проприетарных сервисов и нейросетей) и дополнено интерактивным рабочим местом оператора/аналитика на TypeScript, React и Tailwind CSS.

---

## 1. Архитектура решения на Ruby (`lib/smart_router/`)

1. **`lib/smart_router/provider.rb`** — Модель платёжного партнёра с отслеживанием лимитов (суточные обороты, in-progress счетчики, реквизиты, черные/белые списки банков, маржа, RPM).
2. **`lib/smart_router/operation.rb`** — Модель входящей выплаты (`operation_id`, `amount`, `bank`, `client_id`).
3. **`lib/smart_router/hard_constraints.rb`** — Модуль жестких фильтров (Hard-constraints):
   - Статус провайдера (`active`)
   - Диапазон чека (`limit_amount_min` .. `limit_amount_max`)
   - Дневной лимит (`daily_amount_limit`)
   - Фильтры банков (`banks` и `exclude_banks`)
   - Ограничения In-progress (`in_progress_count_limit`, `in_progress_amount_limit`)
   - Доступность реквизитов/терминалов (`available_requisites > 0`)
   - Маржинальность (`merchant_margin_pct >= provider_margin_pct` либо `allow_negative_agreement`)
   - Интенсивность (`requests_per_minute_limit`)
4. **`lib/smart_router/scoring_engine.rb`** — Движок мягких целей (Soft-goals) и мультикритериального скоринга с поддержкой всех 8 стратегий:
   - `traffic_share` (% от количества заявок)
   - `volume_share` (% от денежного объема)
   - `cascade_priority` (очередь в каскаде по priority)
   - `amount_tier` (диапазоны сумм: 500–50k payflow, 50k–100k vipay, >100k quickpay)
   - `conversion_boost` (по суточной конверсии)
   - `rate_limit_intensity` (балансировка по свободному RPM)
   - `financial_obligations` (дотягивание невыполненных минимальных суточных порогов `daily_turnover_min`)
   - `combined` (взвешенный композитный скоринг всех факторов)
5. **`lib/smart_router/simulation_engine.rb`** — Симулятор выполнения операций:
   - Проверка ответа шлюза на основе конверсии партнера и расчет latency (сек).
   - При отказе или таймауте — автоматический переход к следующему кандидату в каскаде!
   - Если все внешние партнеры исчерпаны — автоматический fallback на `spacepayments`.
6. **`lib/smart_router/analytics_reporter.rb`** — Формирование отчета `routing_report_test.json`:
   - Распределение по провайдерам (факт % vs цель %)
   - Аудит причин пропусков (`skip_reasons`)
   - Прогноз утилизации суточных лимитов (`projected_daily_utilization`)
   - Автоматическая генерация аналитических рекомендаций по изменению долей и расширению лимитов.
7. **`lib/smart_router/router.rb`** — Оркестратор полного пайплайна роутинга.

---

## 2. Команды для проверки и запуска

### Запуск роутера по тестовой очереди
```bash
ruby bin/route_payments.rb --strategy combined --queue operations_queue_test.json
```
Результаты сохраняются в:
- `routing_decisions_test.json`
- `routing_report_test.json`

### Запуск валидатора соответствия спецификации
```bash
ruby data/validate.rb
```
Скрипт проверяет:
- Корректность JSON схем;
- Соблюдение всех Hard-constraints;
- Точность причин исключений (например, `amount_exceeds_limit`, `bank_excluded`);
- Наличие каскада и fallback;
- Структуру отчета распределения и рекомендаций.

### Запуск тестов Ruby (60 тестов: архитектура + числовая точность и крипта)
```bash
# Комплексный сьют (40 тестов логики, стратегий, каскада и ограничений)
ruby test/comprehensive_test_suite.rb

# Числовой сьют (20 тестов: точность float/крипты, микро-чеки 0.0001, защита от деления на 0)
ruby test/test_numeric_precision.rb
```

Либо быстрый смоук-тест:
```bash
ruby test/test_router.rb
```

---

## 3. Сгенерированные артефакты решения

- `routing_decisions_test.json` — Полный список решений с подробными шагами (attempts), причинами пропуска и выбора.
- `routing_report_test.json` — Итоговый аналитический отчет с утилизацией, причинами пропусков и рекомендациями.
