import { useState, useEffect } from 'react';
import { Header } from './components/Header';
import { StrategySelector } from './components/StrategySelector';
import { ProvidersFleet } from './components/ProvidersFleet';
import { OperationsWaterfall } from './components/OperationsWaterfall';
import { AnalyticsDashboard } from './components/AnalyticsDashboard';
import { SimulationSandbox } from './components/SimulationSandbox';
import { ValidationModal } from './components/ValidationModal';
import { ExportModal } from './components/ExportModal';
import { ProvidersMap, Operation, RoutingDecision, RoutingReport, RoutingStrategy } from './types';
import { Layers, BarChart3, Building2, Sparkles, MonitorPlay } from 'lucide-react';
import { safeSum, normalizeProvidersMap } from './lib/formatters';
import { PresentationDeck } from './components/PresentationDeck';

export function App() {
  const [providers, setProviders] = useState<ProvidersMap>({});
  const [queue, setQueue] = useState<Operation[]>([]);
  const [decisions, setDecisions] = useState<RoutingDecision[]>([]);
  const [report, setReport] = useState<RoutingReport | null>(null);
  const [currentStrategy, setCurrentStrategy] = useState<RoutingStrategy>('combined');

  const [activeTab, setActiveTab] = useState<'waterfall' | 'analytics' | 'fleet' | 'sandbox' | 'presentation'>('waterfall');
  const [isRunning, setIsRunning] = useState(false);
  const [isValidating, setIsValidating] = useState(false);
  const [isRunningTests, setIsRunningTests] = useState(false);
  const [validationOutput, setValidationOutput] = useState('');
  const [validationSuccess, setValidationSuccess] = useState(true);
  const [isValidationModalOpen, setIsValidationModalOpen] = useState(false);
  const [isExportModalOpen, setIsExportModalOpen] = useState(false);

  // Fetch initial data
  const fetchData = async () => {
    try {
      const res = await fetch('/api/data');
      if (res.ok) {
        const data = await res.json();
        setProviders(normalizeProvidersMap(data.providers || {}));
        setQueue(Array.isArray(data.queue) ? data.queue : []);
        setDecisions(Array.isArray(data.decisions) ? data.decisions : []);
        setReport(data.report || null);
      }
    } catch (err) {
      console.error('Failed to load initial data:', err);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  // Run ruby router
  const handleRunRouter = async (strategyOverride?: RoutingStrategy) => {
    setIsRunning(true);
    const strategyToUse = strategyOverride || currentStrategy;
    try {
      const res = await fetch('/api/run-ruby-router', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ strategy: strategyToUse, seed: 42 })
      });
      const result = await res.json();
      if (result.success) {
        setDecisions(Array.isArray(result.decisions) ? result.decisions : []);
        setReport(result.report || null);
        if (result.providers) setProviders(normalizeProvidersMap(result.providers));
      }
    } catch (err) {
      console.error('Routing execution error:', err);
    } finally {
      setIsRunning(false);
    }
  };

  // Run validation
  const handleValidate = async () => {
    setIsValidating(true);
    setIsValidationModalOpen(true);
    setValidationOutput('Запуск проверки data/validate.rb...');
    try {
      const res = await fetch('/api/run-ruby-validator', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      });
      const result = await res.json();
      setValidationOutput(result.stdout || result.stderr || 'No output');
      setValidationSuccess(result.success && result.exitCode === 0);
    } catch (err: any) {
      setValidationOutput(`Error executing validator: ${err.message}`);
      setValidationSuccess(false);
    } finally {
      setIsValidating(false);
    }
  };

  // Run 40 comprehensive Ruby tests
  const handleRunTests = async () => {
    setIsRunningTests(true);
    setIsValidationModalOpen(true);
    setValidationOutput('Запуск 40 модульных и интеграционных тестов Ruby...');
    try {
      const res = await fetch('/api/run-ruby-tests', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      });
      const result = await res.json();
      setValidationOutput(result.stdout || result.stderr || 'No output');
      setValidationSuccess(result.success && result.exitCode === 0);
    } catch (err: any) {
      setValidationOutput(`Ошибка при выполнении тестов: ${err.message}`);
      setValidationSuccess(false);
    } finally {
      setIsRunningTests(false);
    }
  };

  // Strategy switch
  const handleSelectStrategy = (strat: RoutingStrategy) => {
    setCurrentStrategy(strat);
    handleRunRouter(strat);
  };

  // Update provider parameters
  const handleUpdateProvider = async (providerId: string, updated: any) => {
    const newProviders = {
      ...providers,
      [providerId]: {
        ...providers[providerId],
        ...updated
      }
    };
    setProviders(newProviders);

    try {
      await fetch('/api/providers', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ providers: newProviders })
      });
      // Re-run router with new provider params
      handleRunRouter();
    } catch (e) {
      console.error('Failed to update provider:', e);
    }
  };

  // Add custom operation to queue
  const handleAddOperationToQueue = async (op: {
    operation_id: string;
    amount: number;
    bank: string;
    client_id: string;
  }) => {
    try {
      const res = await fetch('/api/queue/add', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ operation: op })
      });
      const result = await res.json();
      if (result.success) {
        setQueue(result.queue);
        setDecisions(result.decisions);
        setReport(result.report);
        setActiveTab('waterfall');
      }
    } catch (e) {
      console.error('Failed to add operation:', e);
    }
  };

  // Upload full operations queue from JSON file
  const handleUploadQueue = async (uploadedQueue: Operation[]) => {
    setIsRunning(true);
    try {
      const res = await fetch('/api/queue/upload', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ queue: uploadedQueue, strategy: currentStrategy, seed: 42 })
      });
      const result = await res.json();
      if (result.success) {
        setQueue(Array.isArray(uploadedQueue) ? uploadedQueue : []);
        setDecisions(Array.isArray(result.decisions) ? result.decisions : []);
        setReport(result.report || null);
        if (result.providers) setProviders(normalizeProvidersMap(result.providers));
        setActiveTab('waterfall');
      } else {
        alert(`Ошибка загрузки очереди: ${result.error || 'Неизвестная ошибка'}`);
      }
    } catch (e: any) {
      alert(`Сетевая ошибка при загрузке очереди: ${e.message}`);
    } finally {
      setIsRunning(false);
    }
  };

  const validProvidersCount = Object.keys(providers || {}).filter(
    (k) => !['snapshot_at', 'gateway', 'merchant', 'providers'].includes(k)
  ).length;

  return (
    <div className="min-h-screen bg-slate-50/70 text-slate-900 flex flex-col font-sans selection:bg-indigo-100 selection:text-indigo-900">
      <Header
        onRunRouter={() => handleRunRouter()}
        onValidate={handleValidate}
        onRunTests={handleRunTests}
        onOpenExport={() => setIsExportModalOpen(true)}
        onUploadQueue={handleUploadQueue}
        isRunning={isRunning}
        isValidating={isValidating}
        isRunningTests={isRunningTests}
        totalOperations={(queue || []).length}
        totalVolume={safeSum((queue || []).map(op => op.amount))}
      />

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 w-full space-y-6 flex-1">
        {/* Strategy Selector */}
        <StrategySelector
          currentStrategy={currentStrategy}
          onSelectStrategy={handleSelectStrategy}
        />

        {/* Navigation Tabs */}
        <div className="flex items-center justify-between border-b border-slate-200">
          <div className="flex gap-2 sm:gap-4 overflow-x-auto pb-px">
            <button
              id="tab-waterfall"
              onClick={() => setActiveTab('waterfall')}
              className={`flex items-center gap-2 py-2.5 px-3 text-xs font-semibold border-b-2 transition-colors whitespace-nowrap ${
                activeTab === 'waterfall'
                  ? 'border-indigo-600 text-indigo-700 bg-indigo-50/40 rounded-t-lg'
                  : 'border-transparent text-slate-600 hover:text-slate-900 hover:border-slate-300'
              }`}
            >
              <Layers className="w-4 h-4" />
              <span>Waterfall решений ({(decisions || []).length})</span>
            </button>

            <button
              id="tab-analytics"
              onClick={() => setActiveTab('analytics')}
              className={`flex items-center gap-2 py-2.5 px-3 text-xs font-semibold border-b-2 transition-colors whitespace-nowrap ${
                activeTab === 'analytics'
                  ? 'border-indigo-600 text-indigo-700 bg-indigo-50/40 rounded-t-lg'
                  : 'border-transparent text-slate-600 hover:text-slate-900 hover:border-slate-300'
              }`}
            >
              <BarChart3 className="w-4 h-4" />
              <span>Аналитика и рекомендации</span>
            </button>

            <button
              id="tab-fleet"
              onClick={() => setActiveTab('fleet')}
              className={`flex items-center gap-2 py-2.5 px-3 text-xs font-semibold border-b-2 transition-colors whitespace-nowrap ${
                activeTab === 'fleet'
                  ? 'border-indigo-600 text-indigo-700 bg-indigo-50/40 rounded-t-lg'
                  : 'border-transparent text-slate-600 hover:text-slate-900 hover:border-slate-300'
              }`}
            >
              <Building2 className="w-4 h-4" />
              <span>Провайдеры ({validProvidersCount})</span>
            </button>

            <button
              id="tab-sandbox"
              onClick={() => setActiveTab('sandbox')}
              className={`flex items-center gap-2 py-2.5 px-3 text-xs font-semibold border-b-2 transition-colors whitespace-nowrap ${
                activeTab === 'sandbox'
                  ? 'border-indigo-600 text-indigo-700 bg-indigo-50/40 rounded-t-lg'
                  : 'border-transparent text-slate-600 hover:text-slate-900 hover:border-slate-300'
              }`}
            >
              <Sparkles className="w-4 h-4" />
              <span>Песочница (Sandbox)</span>
            </button>

            <button
              id="tab-presentation"
              onClick={() => setActiveTab('presentation')}
              className={`flex items-center gap-2 py-2.5 px-3 text-xs font-semibold border-b-2 transition-colors whitespace-nowrap ${
                activeTab === 'presentation'
                  ? 'border-indigo-600 text-indigo-700 bg-indigo-50/40 rounded-t-lg font-bold'
                  : 'border-transparent text-slate-600 hover:text-slate-900 hover:border-slate-300'
              }`}
            >
              <MonitorPlay className="w-4 h-4 text-indigo-600" />
              <span>Презентация для жюри (10 слайдов)</span>
            </button>
          </div>

          <div className="hidden lg:flex items-center gap-2 text-xs text-slate-500">
            <span>Каскад отказов: <strong>Active</strong></span>
            <span>•</span>
            <span>Fallback: <strong>SpacePayments</strong></span>
          </div>
        </div>

        {/* Tab Content */}
        {activeTab === 'waterfall' && (
          <div className="space-y-6">
            <OperationsWaterfall
              operations={queue}
              decisions={decisions}
            />
          </div>
        )}

        {activeTab === 'analytics' && (
          <div className="space-y-6">
            <AnalyticsDashboard report={report} />
          </div>
        )}

        {activeTab === 'fleet' && (
          <div className="space-y-6">
            <ProvidersFleet
              providers={providers}
              onUpdateProvider={handleUpdateProvider}
            />
          </div>
        )}

        {activeTab === 'sandbox' && (
          <div className="space-y-6">
            <SimulationSandbox
              providers={providers}
              onAddOperationToQueue={handleAddOperationToQueue}
            />
          </div>
        )}

        {activeTab === 'presentation' && (
          <div className="space-y-6">
            <PresentationDeck />
          </div>
        )}
      </main>

      {/* Footer */}
      <footer className="border-t border-slate-200 bg-white py-4 mt-auto">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex flex-col sm:flex-row items-center justify-between gap-3 text-xs text-slate-500">
          <div className="flex items-center gap-2">
            <span className="font-semibold text-slate-800">Smart Payment Router</span>
            <span>•</span>
            <span>Задача 2: Умный роутинг выплат</span>
          </div>
          <div className="flex items-center gap-4">
            <span className="font-mono text-[11px] text-slate-600">CLI: ruby bin/route_payments.rb</span>
            <span className="font-mono text-[11px] text-slate-600">Tests: ruby data/validate.rb</span>
          </div>
        </div>
      </footer>

      {/* Modals */}
      <ValidationModal
        isOpen={isValidationModalOpen}
        onClose={() => setIsValidationModalOpen(false)}
        output={validationOutput}
        success={validationSuccess}
        isValidating={isValidating}
      />

      <ExportModal
        isOpen={isExportModalOpen}
        onClose={() => setIsExportModalOpen(false)}
        decisions={decisions}
        report={report}
      />
    </div>
  );
}

export default App;
