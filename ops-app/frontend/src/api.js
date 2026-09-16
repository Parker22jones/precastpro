async function request(path, options = {}) {
  const response = await fetch(`/api${path}`, options);
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.error || `Request failed (${response.status})`);
  return payload;
}

const json = (body) => ({
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(body),
});

export const api = {
  health: () => request('/health'),
  previewExcel: (file) => {
    const form = new FormData();
    form.append('file', file);
    return request('/intake/preview', { method: 'POST', body: form });
  },
  importExcel: (file, jobName) => {
    const form = new FormData();
    form.append('file', file);
    if (jobName) form.append('jobName', jobName);
    return request('/intake/import', { method: 'POST', body: form });
  },
  structures: () => request('/structures'),
  scheduleStructures: (structureIds, targetDate) =>
    request('/structures/schedule', json({ structureIds, targetDate })),
  truckLoads: () => request('/truck-loads'),
  createTruckLoad: (driverName, deliveryDate) => request('/truck-loads', json({ driverName, deliveryDate })),
  shippablePieces: () => request('/pieces/shippable'),
  assignPieces: (loadId, pieceIds) => request(`/truck-loads/${loadId}/assign`, json({ pieceIds })),
};
