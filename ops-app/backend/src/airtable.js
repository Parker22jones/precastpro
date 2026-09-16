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

let schemaPromise = null;

/** Field names per table, so imports only write columns that exist in the base. */
export async function getSchema() {
  if (!schemaPromise) {
    schemaPromise = (async () => {
      const baseId = process.env.AIRTABLE_BASE_ID;
      const response = await fetch(`https://api.airtable.com/v0/meta/bases/${baseId}/tables`, {
        headers: { Authorization: `Bearer ${process.env.AIRTABLE_PERSONAL_ACCESS_TOKEN}` },
      });
      if (!response.ok) throw new Error(`Airtable schema request failed (${response.status})`);
      const payload = await response.json();
      return new Map(payload.tables.map((t) => [t.name, new Set(t.fields.map((f) => f.name))]));
    })().catch((err) => {
      schemaPromise = null;
      throw err;
    });
  }
  return schemaPromise;
}

/** The base's own spelling of a field, or null when the base has no such column. */
export async function resolveFieldName(tableName, fieldName) {
  const schema = await getSchema();
  const known = schema.get(tableName);
  if (!known) return fieldName;
  return [...known].find((name) => name.toLowerCase() === fieldName.toLowerCase()) || null;
}

/** Matches on the base's own casing, so "Weight (lbs)" still finds a "Weight (LBS)" column. */
export async function pickExistingFields(tableName, fields) {
  const schema = await getSchema();
  const known = schema.get(tableName);
  if (!known) return fields;
  const byLowerName = new Map([...known].map((name) => [name.toLowerCase(), name]));
  const picked = {};
  for (const [key, value] of Object.entries(fields)) {
    const actual = byLowerName.get(key.toLowerCase());
    if (actual && value != null && value !== '') picked[actual] = value;
  }
  return picked;
}

export async function createRecords(name, rows) {
  const created = await inBatches(rows, (chunk) => table(name).create(chunk, { typecast: true }));
  return created.map((r) => ({ id: r.id, fields: r.fields }));
}

export async function updateRecords(name, rows) {
  const updated = await inBatches(rows, (chunk) => table(name).update(chunk, { typecast: true }));
  return updated.map((r) => ({ id: r.id, fields: r.fields }));
}
