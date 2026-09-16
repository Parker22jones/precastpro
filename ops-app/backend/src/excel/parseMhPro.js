import {
  COLUMN_SYNONYMS,
  PREAMBLE_LABELS,
  classifyComponent,
  mapShippingStatus,
  normalizeHeader,
} from './columnMap.js';
import { readSheets } from './readGrid.js';

const SKIP_ROW_PATTERNS = [/^total weight/i, /^grand total/i, /^page \d+/i];

const cellAt = (row, index) => (index == null ? '' : String(row?.[index] ?? '').trim());

function matchColumn(headers, synonyms) {
  for (const synonym of synonyms) {
    const hit = headers.find((h) => h.text === synonym);
    if (hit) return hit.index;
  }
  for (const synonym of synonyms) {
    const hit = headers.find((h) => h.text.includes(synonym));
    if (hit) return hit.index;
  }
  return null;
}

function headerCells(row) {
  const headers = [];
  row.forEach((value, index) => {
    const text = normalizeHeader(value);
    if (text) headers.push({ index, text });
  });
  return headers;
}

/** The line-item header is the row that matches the most known column names. */
function findHeaderRow(rows) {
  let best = { score: 0, index: -1, headers: [] };
  rows.forEach((row, index) => {
    const headers = headerCells(row);
    let score = 0;
    for (const synonyms of Object.values(COLUMN_SYNONYMS)) {
      if (matchColumn(headers, synonyms) != null) score += 1;
    }
    if (score > best.score) best = { score, index, headers };
  });
  return best;
}

/** Job metadata sits above the header as `label | value` pairs. */
function readPreamble(rows, headerIndex) {
  const values = {};
  for (let rowIndex = 0; rowIndex < headerIndex; rowIndex += 1) {
    const row = rows[rowIndex] || [];
    row.forEach((cell, columnIndex) => {
      const label = normalizeHeader(cell);
      if (!label) return;
      for (const [key, labels] of Object.entries(PREAMBLE_LABELS)) {
        if (values[key] || !labels.includes(label)) continue;
        const value = row.slice(columnIndex + 1).find((next) => String(next ?? '').trim());
        if (value) values[key] = String(value).trim();
      }
    });
  }
  return values;
}

/**
 * Parses an MH Pro order summary (.xlsx or Excel 2003 XML) into `{ job, structures }`.
 * Each line item becomes `quantity` pieces, classified as Base / Riser / Top / Casting.
 */
export async function parseMhProWorkbook(buffer) {
  const sheets = await readSheets(buffer);
  const sheet = sheets.find((candidate) => findHeaderRow(candidate.rows).score >= 3) || sheets[0];
  if (!sheet) throw new Error('Workbook contains no worksheets');

  const header = findHeaderRow(sheet.rows);
  if (header.index < 0 || header.score < 2) {
    throw new Error('Could not locate the line-item header row (expected Structure Name / Description)');
  }
  const columns = Object.fromEntries(
    Object.entries(COLUMN_SYNONYMS).map(([key, synonyms]) => [key, matchColumn(header.headers, synonyms)]),
  );
  if (columns.structureName == null || columns.description == null) {
    throw new Error(
      `Missing a Structure Name or Description column. Headers seen: ${header.headers
        .map((h) => h.text)
        .join(', ')}`,
    );
  }

  const preamble = readPreamble(sheet.rows, header.index);
  const structures = [];
  const byName = new Map();
  const warnings = [];
  let skippedLines = 0;

  for (let rowIndex = header.index + 1; rowIndex < sheet.rows.length; rowIndex += 1) {
    const row = sheet.rows[rowIndex] || [];
    const structureName = cellAt(row, columns.structureName);
    const description = cellAt(row, columns.description);
    if (!structureName) {
      if (description && !SKIP_ROW_PATTERNS.some((pattern) => pattern.test(description))) skippedLines += 1;
      continue;
    }
    if (SKIP_ROW_PATTERNS.some((pattern) => pattern.test(description))) continue;

    let structure = byName.get(structureName);
    if (!structure) {
      structure = { name: structureName, stationNumber: cellAt(row, columns.stationNumber), pieces: [] };
      byName.set(structureName, structure);
      structures.push(structure);
    }

    const quantity = Math.max(1, Math.round(Number.parseFloat(cellAt(row, columns.quantity)) || 1));
    const componentType = classifyComponent(description);
    if (componentType === 'Other') warnings.push(`Unclassified line item: "${description}"`);
    for (let copy = 0; copy < quantity; copy += 1) {
      structure.pieces.push({
        componentType,
        description,
        partWeight: Number.parseFloat(cellAt(row, columns.partWeight)) || null,
        stackPosition: cellAt(row, columns.stackPosition),
        shippingStatus: mapShippingStatus(cellAt(row, columns.status)),
      });
    }
  }

  const job = {
    name: preamble.jobName || sheet.name || 'Imported Job',
    contractor: preamble.contractor || '',
    jobNumber: preamble.jobNumber || '',
    location: preamble.location || '',
  };
  if (!preamble.jobName) warnings.push(`No job name found in the header block; using "${job.name}".`);
  if (skippedLines) warnings.push(`${skippedLines} line items had no structure name and were skipped.`);

  return {
    job,
    structures,
    warnings: [...new Set(warnings)],
    detected: {
      sheet: sheet.name,
      headerRow: header.index + 1,
      headers: header.headers.map((h) => h.text),
      columns: Object.fromEntries(
        Object.entries(columns).filter(([, index]) => index != null).map(([key, index]) => [key, index + 1]),
      ),
    },
  };
}
