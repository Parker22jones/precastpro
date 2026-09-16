import { useEffect, useMemo, useState } from 'react';
import { api } from '../api.js';

export default function ProductionPlanner() {
  const [structures, setStructures] = useState([]);
  const [selected, setSelected] = useState(() => new Set());
  const [jobFilter, setJobFilter] = useState('');
  const [targetDate, setTargetDate] = useState('');
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [busy, setBusy] = useState(false);

  const load = async () => {
    setBusy(true);
    setError('');
    try {
      setStructures(await api.structures());
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

  const jobs = useMemo(
    () => [...new Set(structures.map((s) => s.jobName).filter(Boolean))].sort(),
    [structures],
  );
  const visible = useMemo(
    () => structures.filter((s) => !jobFilter || s.jobName === jobFilter),
    [structures, jobFilter],
  );

  const toggle = (id) =>
    setSelected((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  const toggleAllVisible = (checked) =>
    setSelected((current) => {
      const next = new Set(current);
      for (const structure of visible) {
        if (checked) next.add(structure.id);
        else next.delete(structure.id);
      }
      return next;
    });

  const schedule = async () => {
    setBusy(true);
    setError('');
    setNotice('');
    try {
      const response = await api.scheduleStructures([...selected], targetDate);
      setNotice(`Scheduled ${response.updated} structures for ${response.targetDate}.`);
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const allVisibleSelected = visible.length > 0 && visible.every((s) => selected.has(s.id));

  return (
    <section className="panel">
      <h2>Multi-job batch production planner</h2>
      <div className="toolbar">
        <label className="field">
          <span>Job</span>
          <select value={jobFilter} onChange={(event) => setJobFilter(event.target.value)}>
            <option value="">All jobs</option>
            {jobs.map((job) => (
              <option key={job} value={job}>
                {job}
              </option>
            ))}
          </select>
        </label>
        <label className="field">
          <span>Target production date</span>
          <input
            type="date"
            value={targetDate}
            onChange={(event) => setTargetDate(event.target.value)}
          />
        </label>
        <button
          type="button"
          className="primary"
          disabled={busy || selected.size === 0 || !targetDate}
          onClick={schedule}
        >
          Schedule {selected.size} selected
        </button>
        <button type="button" className="tab" disabled={busy} onClick={load}>
          Refresh
        </button>
      </div>

      {error && <p className="error">{error}</p>}
      {notice && <p className="notice">{notice}</p>}

      <div className="scroll">
        <table>
          <thead>
            <tr>
              <th>
                <input
                  type="checkbox"
                  checked={allVisibleSelected}
                  onChange={(event) => toggleAllVisible(event.target.checked)}
                />
              </th>
              <th>Structure</th>
              <th>Job</th>
              <th>Station</th>
              <th>Status</th>
              <th>Target date</th>
              <th>Pieces</th>
            </tr>
          </thead>
          <tbody>
            {visible.map((structure) => (
              <tr key={structure.id}>
                <td>
                  <input
                    type="checkbox"
                    checked={selected.has(structure.id)}
                    onChange={() => toggle(structure.id)}
                  />
                </td>
                <td>{structure.name}</td>
                <td>{structure.jobName}</td>
                <td>{structure.stationNumber}</td>
                <td>{structure.productionStatus}</td>
                <td>{structure.targetProductionDate || '—'}</td>
                <td>{structure.pieceCount}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {!busy && visible.length === 0 && <p className="muted">No unscheduled structures.</p>}
    </section>
  );
}
