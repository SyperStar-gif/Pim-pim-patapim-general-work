import { useState } from 'react';
import { X, Copy, Download, Check, FileJson } from 'lucide-react';

interface ExportModalProps {
  isOpen: boolean;
  onClose: () => void;
  decisions: any[];
  report: any;
}

export function ExportModal({ isOpen, onClose, decisions, report }: ExportModalProps) {
  const [activeTab, setActiveTab] = useState<'decisions' | 'report'>('decisions');
  const [copied, setCopied] = useState(false);

  if (!isOpen) return null;

  const currentContent = activeTab === 'decisions'
    ? JSON.stringify(decisions, null, 2)
    : JSON.stringify(report, null, 2);

  const filename = activeTab === 'decisions'
    ? 'routing_decisions_test.json'
    : 'routing_report_test.json';

  const copyToClipboard = () => {
    navigator.clipboard.writeText(currentContent);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const downloadFile = () => {
    const blob = new Blob([currentContent], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs">
      <div className="bg-white border border-slate-200 rounded-2xl w-full max-w-4xl overflow-hidden shadow-2xl flex flex-col max-h-[85vh]">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-200 bg-slate-50">
          <div className="flex items-center gap-2">
            <FileJson className="w-5 h-5 text-indigo-600" />
            <h3 className="font-bold text-slate-900 text-sm">Выгрузка артефактов решений</h3>
          </div>
          <button
            onClick={onClose}
            className="p-1 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-200 transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Tabs and Actions */}
        <div className="px-6 py-3 border-b border-slate-100 flex items-center justify-between gap-4">
          <div className="flex gap-2">
            <button
              onClick={() => setActiveTab('decisions')}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
                activeTab === 'decisions'
                  ? 'bg-indigo-600 text-white shadow-xs'
                  : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
              }`}
            >
              routing_decisions_test.json ({decisions.length})
            </button>
            <button
              onClick={() => setActiveTab('report')}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
                activeTab === 'report'
                  ? 'bg-indigo-600 text-white shadow-xs'
                  : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
              }`}
            >
              routing_report_test.json
            </button>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={copyToClipboard}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium border border-slate-300 rounded-lg hover:bg-slate-50 text-slate-700 transition-colors"
            >
              {copied ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5" />}
              <span>{copied ? 'Скопировано!' : 'Копировать'}</span>
            </button>
            <button
              onClick={downloadFile}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold bg-slate-900 text-white rounded-lg hover:bg-slate-800 transition-colors shadow-xs"
            >
              <Download className="w-3.5 h-3.5" />
              <span>Скачать .json</span>
            </button>
          </div>
        </div>

        {/* Code preview */}
        <div className="p-6 overflow-y-auto bg-slate-900 text-slate-100 font-mono text-xs leading-relaxed max-h-[60vh]">
          <pre>{currentContent}</pre>
        </div>

        {/* Footer */}
        <div className="px-6 py-3 bg-slate-50 border-t border-slate-200 flex items-center justify-between text-xs text-slate-500">
          <span>Сгенерировано Ruby Smart Router v1.0</span>
          <button
            onClick={onClose}
            className="px-4 py-1.5 bg-slate-200 text-slate-800 rounded-lg font-medium hover:bg-slate-300"
          >
            Закрыть
          </button>
        </div>
      </div>
    </div>
  );
}
