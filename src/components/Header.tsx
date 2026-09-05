import { Play, CheckCircle2, FileJson, RefreshCw, Cpu, FlaskConical } from 'lucide-react';
import { formatCurrency } from '../lib/formatters';

interface HeaderProps {
  onRunRouter: () => void;
  onValidate: () => void;
  onRunTests: () => void;
  onOpenExport: () => void;
  isRunning: boolean;
  isValidating: boolean;
  isRunningTests: boolean;
  totalOperations: number;
  totalVolume?: number;
}

export function Header({
  onRunRouter,
  onValidate,
  onRunTests,
  onOpenExport,
  isRunning,
  isValidating,
  isRunningTests,
  totalOperations,
  totalVolume
}: HeaderProps) {
  return (
    <header className="border-b border-slate-200 bg-white sticky top-0 z-30 shadow-xs">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3.5 flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-indigo-600 to-blue-700 flex items-center justify-center text-white shadow-sm shadow-indigo-200">
            <Cpu className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-lg font-bold text-slate-900 tracking-tight">Smart Payment Router</h1>
              <span className="px-2 py-0.5 text-xs font-semibold bg-indigo-50 text-indigo-700 rounded-full border border-indigo-200">
                Ruby Engine 3.1
              </span>
            </div>
            <p className="text-xs text-slate-500">
              Умное распределение выплат по стратегиям, каскадный роутинг и аналитика
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 flex-wrap">
          <div className="hidden sm:flex items-center gap-1.5 px-3 py-1.5 bg-slate-50 rounded-lg border border-slate-200 text-xs text-slate-600 mr-1">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            <span>
              В очереди: <strong className="text-slate-900">{totalOperations}</strong> заявок
              {totalVolume !== undefined && totalVolume > 0 && (
                <span className="text-slate-500"> • <strong className="text-slate-800">{formatCurrency(totalVolume)}</strong></span>
              )}
            </span>
          </div>

          <button
            id="run-ruby-router-btn"
            onClick={onRunRouter}
            disabled={isRunning}
            className="inline-flex items-center gap-2 px-3.5 py-2 text-xs font-semibold rounded-lg bg-indigo-600 text-white hover:bg-indigo-700 active:bg-indigo-800 disabled:opacity-50 shadow-xs transition-colors"
          >
            {isRunning ? (
              <RefreshCw className="w-3.5 h-3.5 animate-spin" />
            ) : (
              <Play className="w-3.5 h-3.5 fill-current" />
            )}
            <span>{isRunning ? 'Роутинг...' : 'Запустить роутинг'}</span>
          </button>

          <button
            id="run-ruby-validator-btn"
            onClick={onValidate}
            disabled={isValidating}
            className="inline-flex items-center gap-2 px-3.5 py-2 text-xs font-semibold rounded-lg bg-emerald-600 text-white hover:bg-emerald-700 active:bg-emerald-800 disabled:opacity-50 shadow-xs transition-colors"
          >
            {isValidating ? (
              <RefreshCw className="w-3.5 h-3.5 animate-spin" />
            ) : (
              <CheckCircle2 className="w-3.5 h-3.5" />
            )}
            <span>{isValidating ? 'Проверка...' : 'Валидация JSON'}</span>
          </button>

          <button
            id="run-ruby-tests-btn"
            onClick={onRunTests}
            disabled={isRunningTests}
            className="inline-flex items-center gap-2 px-3.5 py-2 text-xs font-semibold rounded-lg bg-purple-600 text-white hover:bg-purple-700 active:bg-purple-800 disabled:opacity-50 shadow-xs transition-colors"
          >
            {isRunningTests ? (
              <RefreshCw className="w-3.5 h-3.5 animate-spin" />
            ) : (
              <FlaskConical className="w-3.5 h-3.5" />
            )}
            <span>{isRunningTests ? 'Тестирование...' : '60 Тестов (Ruby + Числа)'}</span>
          </button>

          <button
            id="export-files-btn"
            onClick={onOpenExport}
            className="inline-flex items-center gap-2 px-3.5 py-2 text-xs font-semibold rounded-lg border border-slate-300 bg-white text-slate-700 hover:bg-slate-50 transition-colors shadow-xs"
          >
            <FileJson className="w-3.5 h-3.5 text-slate-500" />
            <span>Файлы решений</span>
          </button>
        </div>
      </div>
    </header>
  );
}
