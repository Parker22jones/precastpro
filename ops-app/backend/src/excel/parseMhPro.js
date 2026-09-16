import ExcelJS from 'exceljs';
import { BOM_COLUMNS, COLUMN_SYNONYMS, normalizeHeader } from './columnMap.js';

const HEADER_SCAN_ROWS = 25;

const cellText = (cell) => {
  const value = cell?.value;
  if (value == null) return '';
  if (typeof value === 'object') {
    if (value.text) return String(value.text).trim();
    if (value.result != null) return String(value.result).trim();
    if (value.richText) return value.richText.map((part) => part.text).join('').trim();
    return '';
  }
  return String(value).trim();
};

const cellNumber = (cell) => {
  const text = cellText(cell).replace(/,/g, '');
  const parsed = Number.parseFloat(text);
  return Number.isFinite(parsed) ? parsed : 0;
};

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

/** Picks the row with the most recognizable headers within the first rows of the sheet. */
function findHeaderRow(sheet) {
  let best = { score: 0, rowNumber: null, headers: [] };
  const limit = Math.min(sheet.rowCount, HEADER_SCAN_ROWS);
  for (let rowNumber = 1; rowNumber <= limit; rowNumber += 1) {
    const row = sheet.getRow(rowNumber);
    const headers = [];
    row.eachCell({ includeEmpty: false }, (cell, index) => {
      const text = normalizeHeader(cellText(cell));
      if (text) headers.push({ index, text });
    });
    const known = new Set();
    for (const [key, synonyms] of Object.entries(COLUMN_SYNONYMS)) {
      if (matchColumn(headers, synonyms) != null) known.add(key);
    }
    for (const bom of BOM_COLUMNS) {
      if (matchColumn(headers, bom.synonyms) != null) known.add(bom.componentType);
    }
    if (known.size > best.score) best = { score: known.size, rowNumber, headers };
  }
  return best;
}

function buildColumnIndex(headers) {
  const columns = {};
  for (const [key, synonyms] of Object.entries(COLUMN_SYNONYMS)) {
    columns[key] = matchColumn(headers, synonyms);
  }
  columns.bom = BOM_COLUMNS.map((bom) => ({
    componentType: bom.componentType,
    index: matchColumn(headers, bom.synonyms),
  })).filter((bom) => bom.index != null);
  return columns;
}

/**
 * Parses an MH Pro export into `{ job, structures }`.
 *
 * Handles both export shapes:
 * - wide: one row per structure with a quantity column per BOM category
 * - long: one row per line item with a component/description + quantity column
 */
export async function parseMhProWorkbook(buffer) {
  const workbook = new ExcelJS.Workbook();
  await workbook.xlsx.load(buffer);
  const sheet = workbook.worksheets[0];
  if (!sheet) throw new Error('Workbook contains no worksheets');

  const header = findHeaderRow(sheet);
  if (!header.rowNumber) throw new Error('Could not locate a header row in the worksheet');
  const columns = buildColumnIndex(header.headers);
  if (columns.structureName == null) {
    throw new Error(
      `Could not find a structure column. Headers seen: ${header.headers.map((h) => h.text).join(', ')}`,
    );
  }

  const job = { name: '', contractor: '' };
  const structures = [];
  const byName = new Map();
  const warnings = [];

  for (let rowNumber = header.rowNumber + 1; rowNumber <= sheet.rowCount; rowNumber += 1) {
    const row = sheet.getRow(rowNumber);
    const get = (index) => (index == null ? '' : cellText(row.getCell(index)));

    if (!job.name && get(columns.jobName)) job.name = get(columns.jobName);
    if (!job.contractor && get(columns.contractor)) job.contractor = get(columns.contractor);

    const structureName = get(columns.structureName);
    if (!structureName) continue;

    let structure = byName.get(structureName);
    if (!structure) {
      structure = { name: structureName, stationNumber: get(columns.stationNumber), pieces: [] };
      byName.set(structureName, structure);
      structures.push(structure);
    } else if (!structure.stationNumber) {
      structure.stationNumber = get(columns.stationNumber);
    }

    for (const bom of columns.bom) {
      const quantity = cellNumber(row.getCell(bom.index));
      for (let i = 0; i < quantity; i += 1) structure.pieces.push({ componentType: bom.componentType });
    }

    const componentType = get(columns.componentType);
    if (componentType) {
      const quantity = columns.quantity == null ? 1 : Math.max(1, cellNumber(row.getCell(columns.quantity)));
      for (let i = 0; i < quantity; i += 1) structure.pieces.push({ componentType });
    }
  }

  if (!job.name) {
    job.name = sheet.name || 'Imported Job';
    warnings.push(`No job name column found; using "${job.name}".`);
  }
  for (const structure of structures) {
    if (structure.pieces.length === 0) {
      warnings.push(`Structure "${structure.name}" has no bill-of-materials rows.`);
    }
  }

  return {
    job,
    structures,
    warnings,
    detected: {
      sheet: sheet.name,
      headerRow: header.rowNumber,
      headers: header.headers.map((h) => h.text),
      bomColumns: columns.bom.map((b) => b.componentType),
    },
  };
}
