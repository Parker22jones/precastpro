import ExcelJS from 'exceljs';
import { XMLParser } from 'fast-xml-parser';

/** A sheet is `{ name, rows }` where each row is a 0-indexed array of cell strings. */

const asText = (value) => {
  if (value == null) return '';
  if (value instanceof Date) return value.toISOString();
  if (typeof value === 'object') {
    if (value.text != null) return String(value.text).trim();
    if (value.result != null) return String(value.result).trim();
    if (Array.isArray(value.richText)) return value.richText.map((part) => part.text).join('').trim();
    return '';
  }
  return String(value).trim();
};

function isSpreadsheetXml(buffer) {
  const head = buffer.subarray(0, 512).toString('utf8');
  return head.includes('<?xml') && head.includes('urn:schemas-microsoft-com:office:spreadsheet');
}

async function readXlsx(buffer) {
  const workbook = new ExcelJS.Workbook();
  await workbook.xlsx.load(buffer);
  return workbook.worksheets.map((sheet) => {
    const rows = [];
    for (let rowNumber = 1; rowNumber <= sheet.rowCount; rowNumber += 1) {
      const row = [];
      sheet.getRow(rowNumber).eachCell({ includeEmpty: false }, (cell, index) => {
        row[index - 1] = asText(cell.value);
      });
      rows.push(row);
    }
    return { name: sheet.name, rows };
  });
}

/** Excel 2003 XML (SpreadsheetML), which is what "Order Summary (Excel XML)" exports. */
function readSpreadsheetXml(buffer) {
  const parser = new XMLParser({ ignoreAttributes: false, attributeNamePrefix: '@' });
  const parsed = parser.parse(buffer.toString('utf8'));
  const workbook = parsed.Workbook || parsed['ss:Workbook'];
  if (!workbook) throw new Error('Not a recognizable Excel XML workbook');
  const sheets = [].concat(workbook.Worksheet || []);

  return sheets.map((sheet) => {
    const rows = [];
    let rowIndex = 0;
    for (const xmlRow of [].concat(sheet.Table?.Row || [])) {
      rowIndex = Number(xmlRow['@ss:Index'] || rowIndex + 1);
      const row = [];
      let cellIndex = 0;
      for (const cell of [].concat(xmlRow.Cell || [])) {
        cellIndex = Number(cell['@ss:Index'] || cellIndex + 1);
        const data = cell.Data;
        const text = data && typeof data === 'object' ? data['#text'] : data;
        row[cellIndex - 1] = text == null ? '' : String(text).trim();
      }
      rows[rowIndex - 1] = row;
    }
    for (let i = 0; i < rows.length; i += 1) if (!rows[i]) rows[i] = [];
    return { name: sheet['@ss:Name'] || 'Sheet1', rows };
  });
}

export async function readSheets(buffer) {
  try {
    return isSpreadsheetXml(buffer) ? readSpreadsheetXml(buffer) : await readXlsx(buffer);
  } catch {
    const err = new Error(
      'This file could not be read as a spreadsheet. Export it from MH Pro as .xlsx or "Order Summary (Excel XML)".',
    );
    err.statusCode = 400;
    throw err;
  }
}
