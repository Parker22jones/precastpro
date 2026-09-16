/**
 * Column synonyms for MH Pro order summaries (both the .xlsx and the
 * "Order Summary (Excel XML)" export). Header matching is case/punctuation
 * insensitive: an exact match wins, otherwise the first substring match.
 */
export const COLUMN_SYNONYMS = {
  structureName: ['structure name', 'structure', 'manhole', 'mh id', 'mh no'],
  description: ['description', 'item description', 'product', 'part'],
  quantity: ['quantity', 'qty', 'count'],
  partWeight: ['part weight', 'weight'],
  stackPosition: ['stack position', 'stack'],
  productionDate: ['production date'],
  shippingDate: ['shipping date', 'ship date'],
  status: ['status'],
  notes: ['notes', 'note'],
  stationNumber: ['station number', 'station'],
};

/** Preamble label/value pairs that appear above the line-item header. */
export const PREAMBLE_LABELS = {
  jobName: ['job name', 'project name', 'job'],
  contractor: ['contractor name', 'contractor', 'customer'],
  jobNumber: ['job number', 'job no'],
  location: ['location'],
};

/**
 * Component categories, in priority order: a description is classified by the
 * first category whose pattern matches (parentheticals are stripped first, so
 * "3x3 Alum. Hatch (Cast into top piece)" is a Casting, not a Top).
 */
export const COMPONENT_CATEGORIES = [
  { type: 'Base', pattern: /\bbase\b/i },
  { type: 'Riser', pattern: /\brisers?\b|\bbarrel\b/i },
  { type: 'Top', pattern: /\b(top|cone|slab)\b/i },
  { type: 'Casting', pattern: /\b(hatch|casting|frame|cover|grate|lid|ring|ej)\b|r\/c/i },
  { type: 'Accessory', pattern: /\b(boot|mastic|gasket|sealant|steps?|adapter|wrap|butyl)\b/i },
];

export const normalizeHeader = (value) =>
  String(value ?? '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

export function classifyComponent(description) {
  const withoutParens = String(description || '').replace(/\([^)]*\)/g, ' ');
  for (const category of COMPONENT_CATEGORIES) {
    if (category.pattern.test(withoutParens)) return category.type;
  }
  return 'Other';
}

/** MH Pro status text mapped onto the base's Shipping Status options. */
export function mapShippingStatus(status) {
  const value = String(status || '').trim().toLowerCase();
  if (value === 'owed' || value === 'backordered') return 'Owed';
  if (value === 'shipped') return 'Shipped';
  if (value === 'loaded') return 'Loaded';
  return 'Pending';
}
