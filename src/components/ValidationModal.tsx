import { X, CheckCircle2, AlertTriangle, Terminal } from 'lucide-react';

interface ValidationModalProps {
  isOpen: boolean;
  onClose: () => void;
  output: string;
  success: boolean;
  isValidating: boolean;
}

export function ValidationModal({
  isOpen,
  onClose,
  output,
  success,
  isValidating
}: ValidationModalProps) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs">
      <div className="bg-slate-950 border border-slate-800 rounded-2xl w-full max-w-3xl overflow-hidden shadow-2xl flex flex-col max-h-[85vh]">
        {/* Modal Header */}
        <div className="flex items-center justify-between px-5 py-3.5 border-b border-slate-800 bg-slate-900/80">
          <div className="flex items-center gap-2.5">
            <Terminal className="w-4 h-4 text-emerald-400" />
            <span className="font-mono text-xs font-semibold text-slate-200">
              ruby data/validate.rb
            </span>
            {isValidating ? (
              <span className="px-2 py-0.5 text-[10px] font-mono bg-indigo-950 text-indigo-300 border border-indigo-700 rounded animate-pulse">
                RUNNING...
              </span>
            ) : success ? (
              <span className="px-2 py-0.5 text-[10px] font-mono bg-emerald-950 text-emerald-300 border border-emerald-700 rounded flex items-center gap-1">
                <CheckCircle2 className="w-3 h-3" /> EXIT 0: PASS
              </span>
            ) : (
              <span className="px-2 py-0.5 text-[10px] font-mono bg-rose-950 text-rose-300 border border-rose-700 rounded flex items-center gap-1">
                <AlertTriangle className="w-3 h-3" /> FAILED
              </span>
            )}
          </div>
          <button
            onClick={onClose}
            className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Terminal Content */}
        <div className="p-5 overflow-y-auto font-mono text-xs leading-relaxed text-slate-300 bg-slate-950 space-y-1">
          {isValidating ? (
            <div className="text-slate-400 py-8 text-center animate-pulse">
              Выполнение валидации соответствия hard-constraints и schema JSON...
            </div>
          ) : (
            output.split('\n').map((line, i) => {
              const isPass = line.includes('[PASS]') || line.includes('PASSED');
              const isFail = line.includes('[FAIL]') || line.includes('FAILED');
              const isHeader = line.includes('===') || line.includes('---');

              return (
                <div
                  key={i}
                  className={`${
                    isPass
                      ? 'text-emerald-400 font-semibold'
                      : isFail
                      ? 'text-rose-400 font-bold'
                      : isHeader
                      ? 'text-slate-500'
                      : 'text-slate-300'
                  }`}
                >
                  {line}
                </div>
              );
            })
          )}
        </div>

        {/* Footer */}
        <div className="px-5 py-3 border-t border-slate-800 bg-slate-900/60 flex items-center justify-between text-xs text-slate-400">
          <span>Проверка файлов routing_decisions_test.json и routing_report_test.json</span>
          <button
            onClick={onClose}
            className="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 font-medium transition-colors"
          >
            Закрыть
          </button>
        </div>
      </div>
    </div>
  );
}
