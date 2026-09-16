import express from 'express';
import { createRecords, resolveFieldName, selectAll, updateRecords, TABLES } from '../airtable.js';

const router = express.Router();
const asyncRoute = (handler) => (req, res, next) => handler(req, res, next).catch(next);

/**
 * Pieces are shippable once their structure is poured and they are not yet on a load.
 * The base tracks pour state on Structures, so piece readiness is derived from the parent.
 */
const READY_PRODUCTION_STATUS = 'Poured';
const SHIPPABLE_STATUSES = ['Pending', 'Owed'];

function nextLoadId(existing, deliveryDate) {
  const datePart = (deliveryDate || new Date().toISOString().slice(0, 10)).replace(/-/g, '');
  const prefix = `LD-${datePart}-`;
  const highest = existing
    .map((load) => load.fields['Load ID / Ticket #'] || '')
    .filter((id) => id.startsWith(prefix))
    .map((id) => Number.parseInt(id.slice(prefix.length), 10))
    .filter(Number.isFinite)
    .reduce((max, n) => Math.max(max, n), 0);
  return `${prefix}${String(highest + 1).padStart(3, '0')}`;
}

router.get(
  '/truck-loads',
  asyncRoute(async (_req, res) => {
    const loads = await selectAll(TABLES.truckLoads, {
      sort: [{ field: 'Delivery Date', direction: 'desc' }],
    });
    res.json(
      loads.map((load) => ({
        id: load.id,
        loadId: load.fields['Load ID / Ticket #'] || '',
        driverName: load.fields['Driver Name'] || '',
        deliveryDate: load.fields['Delivery Date'] || null,
        status: load.fields['Load Status'] || '',
        pieceCount: (load.fields['Pieces & Castings'] || []).length,
      })),
    );
  }),
);

router.post(
  '/truck-loads',
  asyncRoute(async (req, res) => {
    const driverName = (req.body.driverName || '').trim();
    const deliveryDate = req.body.deliveryDate || '';
    if (!driverName) {
      const err = new Error('driverName is required');
      err.statusCode = 400;
      throw err;
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(deliveryDate)) {
      const err = new Error('deliveryDate must be an ISO date (YYYY-MM-DD)');
      err.statusCode = 400;
      throw err;
    }
    const existing = await selectAll(TABLES.truckLoads, { fields: ['Load ID / Ticket #'] });
    const [load] = await createRecords(TABLES.truckLoads, [
      {
        fields: {
          'Load ID / Ticket #': nextLoadId(existing, deliveryDate),
          'Driver Name': driverName,
          'Delivery Date': deliveryDate,
          'Load Status': 'Building',
        },
      },
    ]);
    res.json({
      id: load.id,
      loadId: load.fields['Load ID / Ticket #'],
      driverName,
      deliveryDate,
      status: 'Building',
      pieceCount: 0,
    });
  }),
);

router.get(
  '/pieces/shippable',
  asyncRoute(async (_req, res) => {
    const [weightField, [structures, pieces, jobs]] = await Promise.all([
      resolveFieldName(TABLES.pieces, 'Weight (lbs)'),
      Promise.all([
        selectAll(TABLES.structures, {
          filterByFormula: `{Production Status} = '${READY_PRODUCTION_STATUS}'`,
        }),
        selectAll(TABLES.pieces, {
          filterByFormula: `OR(${SHIPPABLE_STATUSES.map((s) => `{Shipping Status} = '${s}'`).join(',')})`,
        }),
        selectAll(TABLES.jobs, { fields: ['Job Name'] }),
      ]),
    ]);
    const jobNames = new Map(jobs.map((job) => [job.id, job.fields['Job Name'] || '']));
    const structureById = new Map(structures.map((s) => [s.id, s]));

    res.json(
      pieces
        .filter((piece) => structureById.has((piece.fields.Structure || [])[0]))
        .map((piece) => {
          const structure = structureById.get(piece.fields.Structure[0]);
          return {
            id: piece.id,
            pieceId: piece.fields['Piece ID'] ?? null,
            componentType: piece.fields['Component Type'] || '',
            shippingStatus: piece.fields['Shipping Status'] || '',
            structureId: structure.id,
            structureName: structure.fields['Structure Name'] || '',
            jobName: jobNames.get((structure.fields.Job || [])[0]) || '',
            weightLbs: weightField ? piece.fields[weightField] ?? null : null,
          };
        }),
    );
  }),
);

router.post(
  '/truck-loads/:loadId/assign',
  asyncRoute(async (req, res) => {
    const { pieceIds } = req.body;
    if (!Array.isArray(pieceIds) || pieceIds.length === 0) {
      const err = new Error('pieceIds must be a non-empty array');
      err.statusCode = 400;
      throw err;
    }
    const updated = await updateRecords(
      TABLES.pieces,
      pieceIds.map((id) => ({
        id,
        fields: { 'Assigned Truck Load': [req.params.loadId], 'Shipping Status': 'Loaded' },
      })),
    );
    res.json({ assigned: updated.length, loadId: req.params.loadId });
  }),
);

export default router;
