import { useEffect, useMemo, useState } from 'react';
import { api } from '../api.js';

/** Two decimals, so the rows a dispatcher reads always add up to the footer total. */
const lbs = (value) => `${value.toLocaleString(undefined, { maximumFractionDigits: 2 })} lbs`;

export default function DispatchScheduler() {
  const [loads, setLoads] = useState([]);
  const [pieces, setPieces] = useState([]);
  const [selected, setSelected] = useState(() => new Set());
  const [activeLoadId, setActiveLoadId] = useState('');
  const [driverName, setDriverName] = useState('');
  const [deliveryDate, setDeliveryDate] = useState('');
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [busy, setBusy] = useState(false);

  const load = async () => {
    setBusy(true);
    setError('');
    try {
      const [nextLoads, nextPieces] = await Promise.all([api.truckLoads(), api.shippablePieces()]);
      setLoads(nextLoads);
      setPieces(nextPieces);
      setSelected(new Set());
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const createLoad = async () => {
    setBusy(true);
    setError('');
    setNotice('');
    try {
      const created = await api.createTruckLoad(driverName, deliveryDate);
      setNotice(`Created load ${created.loadId} for ${created.driverName}.`);
      setActiveLoadId(created.id);
      setDriverName('');
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const assign = async () => {
    setBusy(true);
    setError('');
    setNotice('');
    try {
      const response = await api.assignPieces(activeLoadId, [...selected]);
      setNotice(`Assigned ${response.assigned} pieces to the load.`);
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const allVisibleSelected = pieces.length > 0 && selected.size === pieces.length;
  const toggleAll = () => setSelected(allVisibleSelected ? new Set() : new Set(pieces.map((p) => p.id)));

  const toggle = (id) =>
    setSelected((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  const selectedWeight = useMemo(() => {
    const chosen = pieces.filter((piece) => selected.has(piece.id));
    return {
      total: chosen.reduce((sum, piece) => sum + (piece.weightLbs || 0), 0),
      unknown: chosen.filter((piece) => piece.weightLbs == null).length,
    };
  }, [pieces, selected]);

  const sortedPieces = useMemo(
    () =>
      [...pieces].sort(
        (a, b) => a.jobName.localeCompare(b.jobName) || a.structureName.localeCompare(b.structureName),
      ),
    [pieces],
  );

  return (
    <>
      <section className="panel">
        <h2>New truck load</h2>
        <div className="toolbar">
          <label className="field">
            <span>Driver name</span>
            <input
              type="text"
              value={driverName}
              onChange={(event) => setDriverName(event.target.value)}
            />
          </label>
          <label className="field">
            <span>Delivery date</span>
            <input
              type="date"
              value={deliveryDate}
              onChange={(event) => setDeliveryDate(event.target.value)}
            />
          </label>
          <button
            type="button"
            className="primary"
            disabled={busy || !driverName.trim() || !deliveryDate}
            onClick={createLoad}
          >
            Generate load ticket
          </button>
        </div>
        {error && <p className="error">{error}</p>}
        {notice && <p className="notice">{notice}</p>}
      </section>

      <section className="panel">
        <h2>Ready to ship</h2>
        <div className="toolbar">
          <label className="field">
            <span>Assign to load</span>
            <select value={activeLoadId} onChange={(event) => setActiveLoadId(event.target.value)}>
              <option value="">Select a load…</option>
              {loads.map((truckLoad) => (
                <option key={truckLoad.id} value={truckLoad.id}>
                  {truckLoad.loadId} — {truckLoad.driverName} ({truckLoad.deliveryDate}) ·{' '}
                  {truckLoad.pieceCount} pieces
                </option>
              ))}
            </select>
          </label>
          <button
            type="button"
            className="primary"
            disabled={busy || !activeLoadId || selected.size === 0}
            onClick={assign}
          >
            Assign {selected.size} to load
          </button>
          <button type="button" className="tab" disabled={busy} onClick={load}>
            Refresh
          </button>
        </div>

        <div className="scroll">
          <table>
            <thead>
              <tr>
                <th>
                  <input
                    type="checkbox"
                    title="Select all ready pieces"
                    checked={allVisibleSelected}
                    onChange={toggleAll}
                  />
                </th>
                <th>Piece</th>
                <th>Component</th>
                <th>Structure</th>
                <th>Job</th>
                <th>Weight</th>
                <th>Shipping status</th>
              </tr>
            </thead>
            <tbody>
              {sortedPieces.map((piece) => (
                <tr key={piece.id}>
                  <td>
                    <input
                      type="checkbox"
                      checked={selected.has(piece.id)}
                      onChange={() => toggle(piece.id)}
                    />
                  </td>
                  <td>{piece.pieceId ?? '—'}</td>
                  <td>{piece.componentType}</td>
                  <td>{piece.structureName}</td>
                  <td>{piece.jobName}</td>
                  <td>{piece.weightLbs == null ? '—' : lbs(piece.weightLbs)}</td>
                  <td>{piece.shippingStatus}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="load-total">
          <strong>
            Total load weight: {lbs(selectedWeight.total)} ({selected.size} pieces)
          </strong>
          {selectedWeight.unknown > 0 && (
            <span className="muted">{selectedWeight.unknown} selected pieces have no weight</span>
          )}
        </div>

        {!busy && sortedPieces.length === 0 && (
          <p className="muted">
            No pieces are ready: a piece shows here once its structure is marked Poured and its
            shipping status is Pending or Owed.
          </p>
        )}
      </section>
    </>
  );
}
