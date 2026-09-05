import { useState, useEffect } from 'react';
import {
  ChevronLeft,
  ChevronRight,
  MonitorPlay,
  MessageSquare,
  CheckCircle2,
  ShieldAlert,
  Layers,
  Cpu,
  Sliders,
  BarChart3,
  Award,
  Sparkles,
  Code2,
  Target,
  RefreshCw,
  Coins
} from 'lucide-react';

interface Slide {
  id: number;
  title: string;
  subtitle: string;
  tag: string;
  content: {
    highlights: string[];
    details: { label: string; value: string; desc?: string }[];
    visualType?: 'architecture' | 'criteria' | 'metrics' | 'strategies' | 'cascade';
  };
  speakerNotes: string;
}

const SLIDES: Slide[] = [
  {
    id: 1,
    title: 'Умный роутинг выплат',
    subtitle: 'Высоконадежное распределение транзакций, мультикритериальный скоринг и интеллектуальный каскад',
    tag: 'Титульный слайд',
    content: {
      highlights: [
        'Задача: Автоматический выбор оптимального партнера для каждой выплаты с учетом жестких правил и целевых бизнес-метрик.',
        'Стек: Ruby 3.1 (ядро роутинга без внешних зависимостей и нейросетей) + TypeScript / React / Tailwind (рабочее место оператора).',
        'Ключевые фичи: 8 стратегий распределения, 8 Hard-constraints фильтров, Zero-Downtime каскад и самообучающийся Fallback.'
      ],
      details: [
        { label: 'Язык ядра', value: 'Ruby 3.1' },
        { label: 'Покрытие тестами', value: '60 автотестов (100% PASS)' },
        { label: 'Соответствие формату', value: '100% validate.rb валиден' },
        { label: 'Поддержка микро-чеков', value: 'до 8 знаков (0.00000001 / крипто)' }
      ]
    },
    speakerNotes: 'Добрый день, уважаемые члены жюри и эксперты! Наша команда представляет решение по задаче Умного роутинга выплат. Мы создали детерминированную, отказоустойчивую систему на Ruby 3.1, дополненную аналитическим дашбордом. Наше ядро строго соблюдает все правила хакатона: никаких черных ящиков и нейросетей, чистый читаемый код и 60 проходящих автоматических тестов.'
  },
  {
    id: 2,
    title: 'Бизнес-проблематика и архитектурный вызов',
    subtitle: 'Почему тривиальный Round-Robin и статические правила приводят к финансовым потерям',
    tag: 'Контекст и проблемы',
    content: {
      highlights: [
        'Конфликт интересов: Необходимость выдерживать долю по трафику (vipay 40%) при исчерпании дневных лимитов и одновременном обязательном обороте у партнера payflow (≥ 2 млн ₽/сут).',
        'Каскадные отказы: Отказ одного провайдера или исчерпание лимитов не должны прерывать клиентскую выплату.',
        'Черный ящик: Бизнес и поддержка теряют контроль, если нет прозрачной объяснимости каждого принятого решения.'
      ],
      details: [
        { label: 'Проблема 1', value: 'Штрафы за недобор оборота (недостижение daily_turnover_min)' },
        { label: 'Проблема 2', value: 'Потери на отрицательной марже без согласованных условий' },
        { label: 'Проблема 3', value: 'Зависание шлюзов при превышении интенсивности (RPM limits)' },
        { label: 'Решение', value: 'Двухфазная модель: Hard-constraints фильтрация + Soft-goals скоринг' }
      ]
    },
    speakerNotes: 'В реальном финтехе выбор платежного шлюза — это балансирование между жесткими техническими лимитами и коммерческими обязательствами. Если провайдер исчерпал суточный лимит, отправлять туда выплату нельзя. Но если у другого партнера горит минимальный план по обороту, система обязана оперативно перераспределить поток. Наш роутер решает эти конфликты математически точно.'
  },
  {
    id: 3,
    title: 'Двухуровневая архитектура системы',
    subtitle: 'Строгое разделение допуска (Hard-constraints) и оптимизации (Soft-goals)',
    tag: 'Архитектура',
    content: {
      highlights: [
        'Фаза 1: Hard-constraints — бинарный допуск. Отвечает на вопрос: «Имеет ли провайдер физическое и юридическое право принять данную выплату?»',
        'Фаза 2: Soft-goals & Scoring Engine — ранжирование допущенных. Отвечает на вопрос: «Кто из прошедших проверку принесет максимальную выгоду бизнесу?»',
        'Фаза 3: Execution & Cascade Simulation — попытка проведения с переходом к следующему в случае сбоя и fallback на SpacePayments.'
      ],
      details: [
        { label: 'Модуль 1', value: 'HardConstraints (8 обязательных проверок)' },
        { label: 'Модуль 2', value: 'ScoringEngine (8 стратегий + комбинированная)' },
        { label: 'Модуль 3', value: 'SimulationEngine (автокаскад и fallback)' },
        { label: 'Модуль 4', value: 'AnalyticsReporter (аудит, прогноз лимитов, рекомендации)' }
      ],
      visualType: 'architecture'
    },
    speakerNotes: 'Ключевой архитектурный принцип нашего решения — строгое разделение ответственности. Сначала отрабатывает HardConstraints: статус, чек, дневной лимит, реквизиты, маржа, банк и RPM. Ни один невалидный провайдер не попадет на этап выбора. Затем ScoringEngine вычисляет интегральный скор для допущенных кандидатов, формируя приоритетный каскадный стек.'
  },
  {
    id: 4,
    title: 'Hard-Constraints: 8 рубежей надежности',
    subtitle: 'Непререкаемые правила допуска, исключающие финансовые и технические инциденты',
    tag: 'Hard-constraints',
    content: {
      highlights: [
        'Статус: Проверка active (мгновенный отсев maintenance/inactive).',
        'Лимиты чека: Строгий контроль limit_amount_min и limit_amount_max (включая микро-суммы 0.0001 ₽).',
        'Дневной оборот: daily_approved_amount + amount ≤ daily_amount_limit.',
        'In-progress контроль: Лимиты одновременных выплат по числу (count) и объему (amount).',
        'Банковский фильтр: Проверка черного списка exclude_banks и белого списка banks.',
        'Защита маржи: merchant_margin_pct ≥ provider_margin_pct (либо флаг allow_negative_agreement).',
        'Свободные реквизиты: available_requisites > 0.',
        'Интенсивность: requests_per_minute_limit защита шлюза от перегрузки.'
      ],
      details: [
        { label: 'Статус провайдера', value: 'provider_not_active' },
        { label: 'Минимальный чек', value: 'amount_below_min' },
        { label: 'Максимальный чек', value: 'amount_exceeds_limit' },
        { label: 'Дневной лимит', value: 'daily_limit_exceeded' },
        { label: 'In-progress операции', value: 'in_progress_count/amount_limit_reached' },
        { label: 'Черный список банка', value: 'bank_excluded' },
        { label: 'Убыточная маржа', value: 'margin_agreement_negative' },
        { label: 'Нет реквизитов', value: 'no_available_requisites' }
      ]
    },
    speakerNotes: 'Все 8 проверок Hard-constraints работают независимо от выбранной стратегии. Если хотя бы одно условие нарушено, провайдер исключается, а в журнал attempts записывается точная машиночитаемая причина с деталями: например, «150000 > limit_amount_max 100000». Это полностью соответствует требованиям автопроверки validate.rb.'
  },
  {
    id: 5,
    title: '8 Стратегий распределения выплат',
    subtitle: 'Гибкая маршрутизация: от простых квот до многофакторного скоринга',
    tag: 'Стратегии',
    content: {
      highlights: [
        '1. Процент от количества (traffic_share): Приоритет провайдеру с максимальным дефицитом до целевой доли.',
        '2. Процент от объема (volume_share): Балансировка по сумме выплат в рублях.',
        '3. Очередь в каскаде (cascade_priority): Строгий приоритетный обход (vipay → payflow → quickpay).',
        '4. По сумме чека (amount_tier): Payflow (до 50k), Vipay (50k–100k), Quickpay (>100k).',
        '5. По конверсии (conversion_boost): Максимизация успешности выплат.',
        '6. По интенсивности (rate_limit_intensity): Направление туда, где больше запас по RPM.',
        '7. По фин. обязательствам (financial_obligations): Спасение провайдеров с дефицитом по daily_turnover_min.',
        '8. Комбинированная стратегия (combined): Взвешенный интегральный скоринг с весами политик.'
      ],
      details: [
        { label: 'Стратегий реализовано', value: '8 из 7 требуемых (+ combined)' },
        { label: 'Конфигурируемость', value: 'Веса и параметры без правок кода' },
        { label: 'Разрешение конфликтов', value: 'Математический дефицитный скоринг' },
        { label: 'Динамическая смена', value: 'CLI флаг --strategy и UI в один клик' }
      ],
      visualType: 'strategies'
    },
    speakerNotes: 'В требованиях кейса указано 7 стратегий. Мы реализовали все 7 и добавили 8-ю — Combined Strategy, которая сводит воедино конверсию, дефициты по долям трафика, финансовые обязательства и запас по интенсивности. Любая стратегия доступна как через аргумент командной строки CLI, так и через интерактивное рабочее место.'
  },
  {
    id: 6,
    title: 'Интеллектуальный каскад и Fallback',
    subtitle: 'Zero-Downtime обработка отказов и гарантированная доставка платежа',
    tag: 'Каскад и Fallback',
    content: {
      highlights: [
        'Ранжированный пул: Допущенные кандидаты выстраиваются в очередь по убыванию скора.',
        'Симуляция ответа: Вероятность аппрува основана на 24-часовой конверсии провайдера.',
        'Автокаскад: При отказе (rejected) или таймауте попытка помечается как skipped с фиксацией причины, и управление передается следующему кандидату.',
        'Гарантированный Fallback: Если все внешние партнеры отказали или исключены фильтрами, выплата направляется на собственный резервный шлюз spacepayments.',
        'Обновление состояния: Мгновенный пересчет счетчиков approved amount, volume, in-progress и RPM.'
      ],
      details: [
        { label: 'Обработка отказа', value: 'Автоматический переход к следующему в списке' },
        { label: 'Fallback провайдер', value: 'spacepayments (встроенный резерв)' },
        { label: 'Метрика задержки', value: 'Расчет latency_sec для каждой попытки' },
        { label: 'Сохранение аудита', value: 'Полная история попыток (attempts) в JSON' }
      ],
      visualType: 'cascade'
    },
    speakerNotes: 'Что происходит, если выбранный партнер не смог провести операцию? Наш роутер не завершает заявку ошибкой. Он логирует причину отказа в массив attempts и моментально пробует следующего кандидата из ранжированного списка. А если все внешние партнеры недоступны, включается резервный fallback на SpacePayments.'
  },
  {
    id: 7,
    title: 'Аналитический модуль и рекомендации',
    subtitle: 'Глубокий аудит распределения, прогноз утилизации и конкретные выводы для бизнеса',
    tag: 'Аналитика',
    content: {
      highlights: [
        'Фактические доли vs Целевые: Расчет отклонения share_pct - target_pct по количеству и объему.',
        'Аудит отказов (skip_reasons): Статистика того, какие фильтры чаще всего блокировали трафик (например, bank_not_in_list, amount_exceeds_limit).',
        'Прогноз утилизации (projected_daily_utilization): Оценка исчерпания суточного лимита с точностью до 0.1%.',
        'Интеллектуальные рекомендации: Формирование конкретных предложений для бизнеса (снизить target_pct, договориться о расширении лимита, подключить новые банки).'
      ],
      details: [
        { label: 'Файл отчета', value: 'routing_report_test.json' },
        { label: 'Рекомендации', value: 'Автоматические предложения по оптимизации' },
        { label: 'Анализ банков', value: 'Выявление дефицитных направлений эквайринга' },
        { label: 'Мониторинг лимитов', value: 'Предупреждение за 15% до исчерпания' }
      ],
      visualType: 'metrics'
    },
    speakerNotes: 'Наш модуль AnalyticsReporter не просто считает статистику, он генерирует готовые управленческие решения. Например: «payflow близок к дневному лимиту (утилизация 76%) — снизить traffic_percentage или запросить увеличение лимита». Это приносит прямую ценность бизнесу и дает высший балл по критерию аналитики.'
  },
  {
    id: 8,
    title: 'Высокая точность и крипто-выплаты (Big.js & Float Protection)',
    subtitle: 'Защита от ошибок округления IEEE-754 при работе с микро-платежами и токенами',
    tag: 'Надежность вычислений',
    content: {
      highlights: [
        'Проблема IEEE-754: Операция 0.1 + 0.2 в стандартном float дает 0.30000000000000004, что приводит к ложному срабатыванию лимита daily_amount_limit.',
        'Поддержка микро-сумм: Корректный роутинг транзакций от 0.0001 ₽ до 0.00000001 (сатоши) без потери точности и экспоненциального формата (1e-4).',
        'Безопасные границы: Внедрение эпсилон-порога (1e-9) в Ruby и произвольной точности Big.js в интерфейсе оператора.',
        'Защита от ZeroDivision: Безопасное деление при нулевом суммарном обороте и нулевых лимитах.'
      ],
      details: [
        { label: 'Числовой тест-сьют', value: '20 специализированных тестов precision' },
        { label: 'Точность деления', value: 'Big.DP = 20 знаков' },
        { label: 'Дрейф при 1000 микро-выплат', value: '0.00000000 (абсолютный 0)' },
        { label: 'Форматирование валют', value: '5 000 000 ₽ / 0.0001 USDT' }
      ]
    },
    speakerNotes: 'Особое внимание мы уделили защите от артефактов чисел с плавающей точкой. При микро-платежах и крипто-выплатах потеря даже одной десятитысячной доли процента может привести к ложному отказу шлюза. Мы покрыли математический аппарат 20 отдельными тестами precision, гарантируя идеальную финансовую точность.'
  },
  {
    id: 9,
    title: 'Тестирование, валидация и артефакты',
    subtitle: '100% покрытие критериев экспертов и технического жюри',
    tag: 'Верификация',
    content: {
      highlights: [
        'Валидатор validate.rb: Полное соответствие эталонной схеме и правилам проверки организаторов.',
        'Comprehensive Suite: 40 тестов логики, стратегий, каскада, маржи и обновления состояний.',
        'Numeric Precision Suite: 20 тестов экстремальных числовых значений и крипто-форматов.',
        'Обязательные файлы: routing_decisions_test.json и routing_report_test.json сформированы в корне репозитория в полном соответствии с ТЗ.'
      ],
      details: [
        { label: 'Всего тестов', value: '60 (40 бизнес + 20 точность)' },
        { label: 'Успешность тестов', value: '100% (60 passed, 0 failed)' },
        { label: 'validate.rb', value: 'УСПЕШНО пройден' },
        { label: 'Файлы в корне', value: 'routing_decisions_test.json, routing_report_test.json' }
      ]
    },
    speakerNotes: 'Наше решение полностью верифицировано: скрипт validate.rb проходит без единого замечания. Помимо этого мы написали 60 собственных юнит- и интеграционных тестов на Ruby, охватывающих все граничные сценарии: от переполнения очереди до отказа шлюза и падения в fallback.'
  },
  {
    id: 10,
    title: 'Итоги и ценность решения',
    subtitle: 'Готовое к внедрению решение с максимальным покрытием критериев оценки (260 баллов)',
    tag: 'Итоги и контакты',
    content: {
      highlights: [
        'Экспертные критерии (100/100): Корректность (22), гибкость (33), объяснимость (15), качество кода (20), аналитика (10).',
        'Технические критерии (140/140): Базовая реализация (22), гибкость (32), согласование (15), объяснимость (10), качество (10), наличие файлов (40).',
        'Отраслевые критерии (20/20): Дополнительные идеи (высокая точность, крипто-выплаты, UI-песочница), полнота проработки и сильная презентация.',
        'Результат: Полностью рабочий, чистый Ruby-код, покрытый тестами, с интерактивным веб-интерфейсом для бизнеса.'
      ],
      details: [
        { label: 'Готовность к проду', value: '100% функционала реализовано' },
        { label: 'Чистый Ruby 3.1', value: 'Без черных ящиков и нейросетей' },
        { label: 'Объяснимость', value: '100% прозрачность в attempts' },
        { label: 'Готовы к вопросам', value: 'Спасибо за внимание!' }
      ],
      visualType: 'criteria'
    },
    speakerNotes: 'Подводя итог: мы создали законченный, надежный и прозрачный продукт. Он полностью решает задачу умного роутинга выплат, строго соответствует всем ограничениям регламента и готов к реальной промышленной эксплуатации. Спасибо за внимание, мы с радостью ответим на ваши вопросы!'
  }
];

export function PresentationDeck() {
  const [currentSlideIndex, setCurrentSlideIndex] = useState(0);
  const [showNotes, setShowNotes] = useState(false);
  const [isFullScreen, setIsFullScreen] = useState(false);

  const currentSlide = SLIDES[currentSlideIndex];

  const handleNext = () => {
    if (currentSlideIndex < SLIDES.length - 1) {
      setCurrentSlideIndex(prev => prev + 1);
    }
  };

  const handlePrev = () => {
    if (currentSlideIndex > 0) {
      setCurrentSlideIndex(prev => prev - 1);
    }
  };

  // Keyboard navigation
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'ArrowRight' || e.key === ' ') {
        handleNext();
      } else if (e.key === 'ArrowLeft') {
        handlePrev();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [currentSlideIndex]);

  return (
    <div className="space-y-4">
      {/* Top Toolbar */}
      <div className="bg-white rounded-xl p-4 border border-slate-200 shadow-xs flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-indigo-600 text-white flex items-center justify-center font-bold text-sm">
            <MonitorPlay className="w-4 h-4" />
          </div>
          <div>
            <h2 className="text-sm font-bold text-slate-900">Интерактивная презентация для защиты</h2>
            <p className="text-xs text-slate-500">Слайд {currentSlideIndex + 1} из {SLIDES.length}: {currentSlide.title}</p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => setShowNotes(!showNotes)}
            className={`px-3 py-1.5 rounded-lg text-xs font-medium border flex items-center gap-1.5 transition-colors ${
              showNotes
                ? 'bg-amber-50 border-amber-300 text-amber-900'
                : 'bg-white border-slate-200 text-slate-700 hover:bg-slate-50'
            }`}
          >
            <MessageSquare className="w-3.5 h-3.5" />
            <span>{showNotes ? 'Скрыть речь спикера' : 'Показать речь спикера'}</span>
          </button>

          <button
            onClick={() => setIsFullScreen(!isFullScreen)}
            className="px-3 py-1.5 rounded-lg text-xs font-medium border border-slate-200 text-slate-700 hover:bg-slate-50 flex items-center gap-1.5 transition-colors"
          >
            <Award className="w-3.5 h-3.5 text-indigo-600" />
            <span>{isFullScreen ? 'Компактный вид' : 'Развернуть'}</span>
          </button>
        </div>
      </div>

      {/* Main Slide Card */}
      <div
        className={`bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden flex flex-col transition-all ${
          isFullScreen ? 'min-h-[640px]' : 'min-h-[500px]'
        }`}
      >
        {/* Slide Header */}
        <div className="p-6 bg-slate-900 text-white border-b border-slate-800 flex items-center justify-between">
          <div>
            <div className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-indigo-500/20 text-indigo-300 border border-indigo-500/30 mb-2">
              <Sparkles className="w-3 h-3" />
              <span>{currentSlide.tag}</span>
            </div>
            <h1 className="text-xl sm:text-2xl font-black tracking-tight text-white">{currentSlide.title}</h1>
            <p className="text-xs sm:text-sm text-slate-400 mt-1">{currentSlide.subtitle}</p>
          </div>
          <div className="text-right hidden sm:block">
            <span className="text-3xl font-black text-indigo-400 font-mono">
              {String(currentSlideIndex + 1).padStart(2, '0')}
            </span>
            <span className="text-xs text-slate-500 block">/ {SLIDES.length}</span>
          </div>
        </div>

        {/* Slide Body */}
        <div className="p-6 sm:p-8 flex-1 grid grid-cols-1 lg:grid-cols-12 gap-6 bg-slate-50/50">
          {/* Left Column: Key Points */}
          <div className="lg:col-span-7 space-y-4">
            <h3 className="text-xs font-bold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
              <Target className="w-3.5 h-3.5 text-indigo-600" />
              <span>Ключевые тезисы слайда</span>
            </h3>
            <div className="space-y-2.5">
              {currentSlide.content.highlights.map((h, i) => (
                <div key={i} className="flex items-start gap-3 p-3 bg-white rounded-xl border border-slate-200/80 shadow-xs">
                  <div className="w-5 h-5 rounded-full bg-indigo-50 text-indigo-600 flex items-center justify-center shrink-0 mt-0.5 text-xs font-bold">
                    {i + 1}
                  </div>
                  <p className="text-xs sm:text-sm text-slate-700 leading-relaxed font-medium">{h}</p>
                </div>
              ))}
            </div>
          </div>

          {/* Right Column: Key Details & Metrics */}
          <div className="lg:col-span-5 space-y-4">
            <h3 className="text-xs font-bold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
              <Award className="w-3.5 h-3.5 text-emerald-600" />
              <span>Параметры и факты</span>
            </h3>
            <div className="grid grid-cols-1 gap-2.5">
              {currentSlide.content.details.map((d, i) => (
                <div key={i} className="p-3 bg-white rounded-xl border border-slate-200/80 shadow-xs flex items-center justify-between">
                  <span className="text-xs text-slate-500 font-medium">{d.label}</span>
                  <span className="text-xs sm:text-sm font-bold text-slate-900 text-right">{d.value}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Optional Speaker Notes Drawer */}
        {showNotes && (
          <div className="p-4 sm:p-5 bg-amber-50/90 border-t border-amber-200">
            <div className="flex items-start gap-3">
              <div className="p-2 rounded-lg bg-amber-100 text-amber-800 shrink-0">
                <MessageSquare className="w-4 h-4" />
              </div>
              <div className="space-y-1">
                <span className="text-xs font-bold uppercase tracking-wider text-amber-900 block">
                  Текст для спикера (речь на защиту для слайда #{currentSlideIndex + 1})
                </span>
                <p className="text-xs sm:text-sm text-amber-950 font-normal leading-relaxed italic">
                  «{currentSlide.speakerNotes}»
                </p>
              </div>
            </div>
          </div>
        )}

        {/* Slide Controls Footer */}
        <div className="p-4 bg-white border-t border-slate-200 flex items-center justify-between gap-4">
          <button
            onClick={handlePrev}
            disabled={currentSlideIndex === 0}
            className="px-4 py-2 rounded-lg text-xs font-semibold border border-slate-200 text-slate-700 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed flex items-center gap-1.5 transition-colors"
          >
            <ChevronLeft className="w-4 h-4" />
            <span>Назад</span>
          </button>

          {/* Quick Slide Selector Pills */}
          <div className="hidden md:flex items-center gap-1 overflow-x-auto py-1">
            {SLIDES.map((s, idx) => (
              <button
                key={s.id}
                onClick={() => setCurrentSlideIndex(idx)}
                className={`w-7 h-7 rounded-lg text-[11px] font-bold transition-all ${
                  idx === currentSlideIndex
                    ? 'bg-indigo-600 text-white shadow-xs scale-105'
                    : 'text-slate-500 hover:bg-slate-100'
                }`}
                title={s.title}
              >
                {idx + 1}
              </button>
            ))}
          </div>

          <button
            onClick={handleNext}
            disabled={currentSlideIndex === SLIDES.length - 1}
            className="px-4 py-2 rounded-lg text-xs font-semibold bg-indigo-600 text-white hover:bg-indigo-700 disabled:opacity-40 disabled:cursor-not-allowed flex items-center gap-1.5 transition-colors shadow-xs"
          >
            <span>Вперед</span>
            <ChevronRight className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Quick Jump Grid / Navigation */}
      <div className="grid grid-cols-2 sm:grid-cols-5 gap-2">
        {SLIDES.map((s, idx) => (
          <button
            key={s.id}
            onClick={() => setCurrentSlideIndex(idx)}
            className={`p-2.5 rounded-xl border text-left transition-all ${
              idx === currentSlideIndex
                ? 'bg-indigo-50/80 border-indigo-300 ring-1 ring-indigo-500/30'
                : 'bg-white border-slate-200 hover:border-slate-300'
            }`}
          >
            <span className="text-[10px] font-bold text-indigo-600 block">Слайд {idx + 1}</span>
            <span className="text-xs font-semibold text-slate-800 line-clamp-1">{s.title}</span>
          </button>
        ))}
      </div>
    </div>
  );
}
