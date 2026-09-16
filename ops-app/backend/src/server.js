import 'dotenv/config';
import cors from 'cors';
import express from 'express';
import intakeRouter from './routes/intake.js';
import plannerRouter from './routes/planner.js';
import dispatchRouter from './routes/dispatch.js';

const app = express();
app.use(cors());
app.use(express.json({ limit: '5mb' }));

app.get('/api/health', (_req, res) => {
  res.json({
    ok: true,
    airtableConfigured: Boolean(
      process.env.AIRTABLE_PERSONAL_ACCESS_TOKEN && process.env.AIRTABLE_BASE_ID,
    ),
  });
});

app.use('/api/intake', intakeRouter);
app.use('/api', plannerRouter);
app.use('/api', dispatchRouter);

app.use((err, _req, res, _next) => {
  const status = err.statusCode && err.statusCode >= 400 ? err.statusCode : 500;
  console.error(err);
  res.status(status).json({ error: err.message || 'Unexpected server error' });
});

const port = Number(process.env.PORT) || 4000;
app.listen(port, () => {
  console.log(`Precast ops backend listening on http://localhost:${port}`);
});
