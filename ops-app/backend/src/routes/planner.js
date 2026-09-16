import express from 'express';
import { selectAll, updateRecords, TABLES } from '../airtable.js';

const router = express.Router();
const asyncRoute = (handler) => (req, res, next) => handler(req, res, next).catch(next);

const PLANNABLE = ['Not Started', 'Scheduled'];

async function jobNamesById() {
  const jobs = await selectAll(TABLES.jobs, { fields: ['Job Name'] });
  return new Map(jobs.map((job) => [job.id, job.fields['Job Name'] || '(unnamed job)']));
}

router.get(
  '/structures',
  asyncRoute(async (req, res) => {
    const statuses = req.query.status ? String(req.query.status).split(',') : PLANNABLE;
    const [structures, jobNames] = await Promise.all([
      selectAll(TABLES.structures, {
        filterByFormula: `OR(${statuses.map((s) => `{Production Status} = '${s}'`).join(',')})`,
        sort: [{ field: 'Structure Name' }],
      }),
      jobNamesById(),
    ]);
    res.json(
      structures.map((structure) => ({
        id: structure.id,
        name: structure.fields['Structure Name'] || '',
        jobId: (structure.fields.Job || [])[0] || null,
        jobName: jobNames.get((structure.fields.Job || [])[0]) || '',
        stationNumber: structure.fields['Station Number'] || '',
        productionStatus: structure.fields['Production Status'] || '',
        targetProductionDate: structure.fields['Target Production Date'] || null,
        pieceCount: (structure.fields['Pieces & Castings'] || []).length,
      })),
    );
  }),
);

router.post(
  '/structures/schedule',
  asyncRoute(async (req, res) => {
    const { structureIds, targetDate } = req.body;
    if (!Array.isArray(structureIds) || structureIds.length === 0) {
      const err = new Error('structureIds must be a non-empty array');
      err.statusCode = 400;
      throw err;
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(targetDate || '')) {
      const err = new Error('targetDate must be an ISO date (YYYY-MM-DD)');
      err.statusCode = 400;
      throw err;
    }
    const updated = await updateRecords(
      TABLES.structures,
      structureIds.map((id) => ({
        id,
        fields: { 'Target Production Date': targetDate, 'Production Status': 'Scheduled' },
      })),
    );
    res.json({ updated: updated.length, targetDate });
  }),
);

export default router;
