import express from 'express';
import multer from 'multer';
import { createRecords, pickExistingFields, selectAll, TABLES } from '../airtable.js';
import { parseMhProWorkbook } from '../excel/parseMhPro.js';

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 20 * 1024 * 1024 } });

const asyncRoute = (handler) => (req, res, next) => handler(req, res, next).catch(next);

const requireFile = (req) => {
  if (!req.file) {
    const err = new Error('No file uploaded. Send an .xlsx file in the "file" field.');
    err.statusCode = 400;
    throw err;
  }
  return req.file.buffer;
};

router.post(
  '/preview',
  upload.single('file'),
  asyncRoute(async (req, res) => {
    const parsed = await parseMhProWorkbook(requireFile(req));
    const pieces = parsed.structures.flatMap((structure) => structure.pieces);
    const byType = {};
    for (const piece of pieces) byType[piece.componentType] = (byType[piece.componentType] || 0) + 1;
    res.json({
      ...parsed,
      totals: {
        structures: parsed.structures.length,
        pieces: pieces.length,
        byType,
        weightLbs: Math.round(pieces.reduce((sum, piece) => sum + (piece.partWeight || 0), 0)),
      },
    });
  }),
);

router.post(
  '/import',
  upload.single('file'),
  asyncRoute(async (req, res) => {
    const parsed = await parseMhProWorkbook(requireFile(req));
    const jobName = (req.body.jobName || parsed.job.name).trim();

    const existingJobs = await selectAll(TABLES.jobs, { fields: ['Job Name'] });
    const existing = existingJobs.find((j) => (j.fields['Job Name'] || '').trim() === jobName);
    const job =
      existing ||
      (
        await createRecords(TABLES.jobs, [
          {
            fields: await pickExistingFields(TABLES.jobs, {
              'Job Name': jobName,
              Contractor: req.body.contractor || parsed.job.contractor || '',
              Status: 'Active',
              'Job Number': parsed.job.jobNumber,
              Location: parsed.job.location,
            }),
          },
        ])
      )[0];

    const structures = await createRecords(
      TABLES.structures,
      await Promise.all(
        parsed.structures.map(async (structure) => ({
          fields: await pickExistingFields(TABLES.structures, {
            'Structure Name': structure.name,
            Job: [job.id],
            'Station Number': structure.stationNumber || '',
            'Production Status': 'Not Started',
          }),
        })),
      ),
    );

    const pieceRows = [];
    for (const [index, structure] of parsed.structures.entries()) {
      for (const piece of structure.pieces) {
        pieceRows.push({
          fields: await pickExistingFields(TABLES.pieces, {
            Structure: [structures[index].id],
            'Component Type': piece.componentType,
            'Shipping Status': piece.shippingStatus,
            'Weight (lbs)': piece.partWeight == null ? null : Math.round(piece.partWeight * 100) / 100,
            Description: piece.description,
            'Stack Position': piece.stackPosition,
          }),
        });
      }
    }
    const pieces = await createRecords(TABLES.pieces, pieceRows);

    res.json({
      job: { id: job.id, name: jobName, created: !existing },
      created: { structures: structures.length, pieces: pieces.length },
      warnings: parsed.warnings,
      detected: parsed.detected,
    });
  }),
);

export default router;
