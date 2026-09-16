/**
 * Column synonyms for MH Pro exports. Header matching is case/space/punctuation
 * insensitive; the first synonym that appears as a substring of a header wins.
 * Adjust these once a real MH Pro export is available.
 */
export const COLUMN_SYNONYMS = {
  jobName: ['job name', 'project name', 'job', 'project'],
  contractor: ['contractor', 'customer', 'client'],
  structureName: ['structure name', 'structure', 'manhole', 'mh id', 'mh no', 'structure id'],
  stationNumber: ['station number', 'station', 'sta'],
  componentType: ['component', 'item', 'description', 'product', 'part'],
  quantity: ['quantity', 'qty', 'count'],
};

/**
 * Quantity columns in "wide" exports: one column per bill-of-materials category.
 * Each entry expands into that many Pieces & Castings rows per structure.
 */
export const BOM_COLUMNS = [
  { componentType: 'Base', synonyms: ['base'] },
  { componentType: 'Riser', synonyms: ['riser', 'barrel', 'section'] },
  { componentType: 'Top', synonyms: ['top', 'cone', 'flat top', 'slab top'] },
  { componentType: 'Casting', synonyms: ['casting', 'frame', 'cover', 'grate', 'lid'] },
];

export const normalizeHeader = (value) =>
  String(value ?? '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
