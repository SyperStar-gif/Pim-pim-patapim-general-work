import express from 'express';
import path from 'path';
import fs from 'fs';
import { exec } from 'child_process';
import { fileURLToPath } from 'url';
import { createServer as createViteServer } from 'vite';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function startServer() {
  const app = express();
  const PORT = 3000;

  app.use(express.json({ limit: '10mb' }));

  // Helper to read JSON safely
  const readJsonSafe = (filepath: string, fallback: any = null) => {
    try {
      if (fs.existsSync(filepath)) {
        return JSON.parse(fs.readFileSync(filepath, 'utf-8'));
      }
    } catch (e) {
      console.error(`Error reading ${filepath}:`, e);
    }
    return fallback;
  };

  // API 1: Health check
  app.get('/api/health', (req, res) => {
    res.json({
      status: 'ok',
      ruby_available: true,
      timestamp: new Date().toISOString()
    });
  });

  // API 2: Get all datasets and current results
  app.get('/api/data', (req, res) => {
    try {
      const providers = readJsonSafe(path.join(__dirname, 'data/providers.json'), {});
      const queue = readJsonSafe(path.join(__dirname, 'operations_queue_test.json'), readJsonSafe(path.join(__dirname, 'data/operations_queue.json'), []));
      const decisions = readJsonSafe(path.join(__dirname, 'routing_decisions_test.json'), readJsonSafe(path.join(__dirname, 'data/sample_routing_decisions.json'), []));
      const report = readJsonSafe(path.join(__dirname, 'routing_report_test.json'), {});

      let historyCsv = '';
      const csvPath = path.join(__dirname, 'data/operations_history.csv');
      if (fs.existsSync(csvPath)) {
        historyCsv = fs.readFileSync(csvPath, 'utf-8');
      }

      res.json({
        providers,
        queue,
        decisions,
        report,
        historyCount: historyCsv.trim().split('\n').length - 1
      });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  });

  // API 3: Run the Ruby router CLI
  app.post('/api/run-ruby-router', (req, res) => {
    const { strategy = 'combined', seed = 42 } = req.body || {};
    const safeStrategy = ['combined', 'traffic_share', 'volume_share', 'cascade_priority', 'amount_tier', 'conversion_boost', 'rate_limit_intensity', 'financial_obligations'].includes(strategy)
      ? strategy
      : 'combined';

    const cmd = `ruby bin/route_payments.rb --strategy ${safeStrategy} --seed ${parseInt(seed, 10) || 42}`;

    exec(cmd, { cwd: __dirname }, (error, stdout, stderr) => {
      const decisions = readJsonSafe(path.join(__dirname, 'routing_decisions_test.json'), []);
      const report = readJsonSafe(path.join(__dirname, 'routing_report_test.json'), {});
      const providers = readJsonSafe(path.join(__dirname, 'data/providers.json'), {});

      res.json({
        success: !error,
        exitCode: error ? error.code : 0,
        stdout,
        stderr,
        strategy: safeStrategy,
        decisions,
        report,
        providers
      });
    });
  });

  // API 4: Run Ruby validator (both official validate.rb and validate_10.rb)
  app.post('/api/run-ruby-validator', (req, res) => {
    const cmd = `ruby data/validate.rb && ruby data/validate_10.rb routing_decisions_test.json`;

    exec(cmd, { cwd: __dirname }, (error, stdout, stderr) => {
      res.json({
        success: !error,
        exitCode: error ? error.code : 0,
        stdout,
        stderr
      });
    });
  });

  // API 4b: Run Ruby test suites (all 8 suites: comprehensive, precision, scenarios, advanced, resilience, self-healing, risk, fees)
  app.post('/api/run-ruby-tests', (req, res) => {
    const cmd = `ruby test/master_test_runner.rb`;

    exec(cmd, { cwd: __dirname }, (error, stdout, stderr) => {
      res.json({
        success: !error,
        exitCode: error ? error.code : 0,
        stdout,
        stderr
      });
    });
  });

  // API 5: Update providers configuration
  app.post('/api/providers', (req, res) => {
    try {
      const { providers } = req.body;
      if (!providers || typeof providers !== 'object') {
        return res.status(400).json({ error: 'Invalid providers payload' });
      }
      fs.writeFileSync(path.join(__dirname, 'data/providers.json'), JSON.stringify(providers, null, 2));
      res.json({ success: true, providers });
    } catch (e: any) {
      res.status(500).json({ error: e.message });
    }
  });

  // API 6: Update or add operation to queue
  app.post('/api/queue/add', (req, res) => {
    try {
      const { operation } = req.body;
      if (!operation || !operation.operation_id || !operation.amount || !operation.bank) {
        return res.status(400).json({ error: 'Invalid operation fields' });
      }

      const queuePath = path.join(__dirname, 'operations_queue_test.json');
      const queue = readJsonSafe(queuePath, []);
      queue.push(operation);
      fs.writeFileSync(queuePath, JSON.stringify(queue, null, 2));
      fs.writeFileSync(path.join(__dirname, 'data/operations_queue.json'), JSON.stringify(queue, null, 2));

      // Auto re-route
      exec(`ruby bin/route_payments.rb`, { cwd: __dirname }, (err, stdout, stderr) => {
        const decisions = readJsonSafe(path.join(__dirname, 'routing_decisions_test.json'), []);
        const report = readJsonSafe(path.join(__dirname, 'routing_report_test.json'), {});
        res.json({
          success: true,
          queue,
          decisions,
          report,
          stdout
        });
      });
    } catch (e: any) {
      res.status(500).json({ error: e.message });
    }
  });

  // API 7: Upload and replace whole operations queue (drag-and-drop or file upload for tomorrow's final file)
  app.post('/api/queue/upload', (req, res) => {
    try {
      const { queue, strategy = 'combined', seed = 42 } = req.body;
      if (!Array.isArray(queue)) {
        return res.status(400).json({ error: 'Queue must be an array of operations' });
      }

      const queuePath = path.join(__dirname, 'operations_queue_test.json');
      fs.writeFileSync(queuePath, JSON.stringify(queue, null, 2));
      fs.writeFileSync(path.join(__dirname, 'data/operations_queue.json'), JSON.stringify(queue, null, 2));

      // Run Ruby routing immediately on newly uploaded queue
      const safeStrategy = ['combined', 'traffic_share', 'volume_share', 'cascade_priority', 'amount_tier', 'conversion_boost', 'rate_limit_intensity', 'financial_obligations'].includes(strategy)
        ? strategy
        : 'combined';

      const cmd = `ruby bin/route_payments.rb -q ${queuePath} --strategy ${safeStrategy} --seed ${parseInt(seed, 10) || 42}`;

      exec(cmd, { cwd: __dirname }, (err, stdout, stderr) => {
        const decisions = readJsonSafe(path.join(__dirname, 'routing_decisions_test.json'), []);
        const report = readJsonSafe(path.join(__dirname, 'routing_report_test.json'), {});
        const providers = readJsonSafe(path.join(__dirname, 'data/providers.json'), {});

        res.json({
          success: !err,
          queueCount: queue.length,
          strategy: safeStrategy,
          decisions,
          report,
          providers,
          stdout,
          stderr
        });
      });
    } catch (e: any) {
      res.status(500).json({ error: e.message });
    }
  });

  // Vite middleware for development
  if (process.env.NODE_ENV !== 'production') {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), 'dist');
    app.use(express.static(distPath));
    app.get('*', (req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

startServer();
