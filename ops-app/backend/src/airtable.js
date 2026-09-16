import Airtable from 'airtable';

export const TABLES = {
  jobs: 'Jobs',
  structures: 'Structures',
  pieces: 'Pieces & Castings',
  truckLoads: 'Truck Loads',
};

let cachedBase = null;

export function getBase() {
  if (cachedBase) return cachedBase;
  const apiKey = process.env.AIRTABLE_PERSONAL_ACCESS_TOKEN;
  const baseId = process.env.AIRTABLE_BASE_ID;
  if (!apiKey || !baseId) {
    throw new Error(
      'Missing AIRTABLE_PERSONAL_ACCESS_TOKEN or AIRTABLE_BASE_ID. Copy ops-app/backend/.env.example to .env and fill it in.',
    );
  }
  cachedBase = new Airtable({ apiKey }).base(baseId);
  return cachedBase;
}

export function table(name) {
  return getBase()(name);
}

export async function selectAll(name, options = {}) {
  const records = await table(name).select(options).all();
  return records.map((r) => ({ id: r.id, fields: r.fields }));
}

/** Airtable caps create/update batches at 10 records. */
export async function inBatches(items, worker, size = 10) {
  const results = [];
  for (let i = 0; i < items.length; i += size) {
    results.push(...(await worker(items.slice(i, i + size))));
  }
  return results;
}

export async function createRecords(name, rows) {
  const created = await inBatches(rows, (chunk) => table(name).create(chunk, { typecast: true }));
  return created.map((r) => ({ id: r.id, fields: r.fields }));
}

export async function updateRecords(name, rows) {
  const updated = await inBatches(rows, (chunk) => table(name).update(chunk, { typecast: true }));
  return updated.map((r) => ({ id: r.id, fields: r.fields }));
}
