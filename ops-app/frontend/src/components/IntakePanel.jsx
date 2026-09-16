import { useRef, useState } from 'react';
import { api } from '../api.js';

export default function IntakePanel() {
  const [dragging, setDragging] = useState(false);
  const [file, setFile] = useState(null);
  const [preview, setPreview] = useState(null);
  const [result, setResult] = useState(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const inputRef = useRef(null);

  const handleFile = async (selected) => {
    setError('');
    setResult(null);
    setPreview(null);
    setFile(selected);
    if (!selected) return;
    if (!selected.name.toLowerCase().endsWith('.xlsx')) {
      setError('Please drop an .xlsx file exported from MH Pro.');
      return;
    }
    setBusy(true);
    try {
      setPreview(await api.previewExcel(selected));
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const runImport = async () => {
    setBusy(true);
    setError('');
    try {
      setResult(await api.importExcel(file));
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <section className="panel">
      <h2>MH Pro Excel intake</h2>
      <div
        className={dragging ? 'dropzone dragging' : 'dropzone'}
        onDragOver={(event) => {
          event.preventDefault();
          setDragging(true);
        }}
        onDragLeave={() => setDragging(false)}
        onDrop={(event) => {
          event.preventDefault();
          setDragging(false);
          handleFile(event.dataTransfer.files[0]);
        }}
        onClick={() => inputRef.current?.click()}
      >
        <p>{file ? file.name : 'Drag an MH Pro .xlsx export here, or click to browse'}</p>
        <input
          ref={inputRef}
          type="file"
          accept=".xlsx"
          hidden
          onChange={(event) => handleFile(event.target.files[0])}
        />
      </div>

      {error && <p className="error">{error}</p>}
      {busy && <p className="notice">Working…</p>}

      {preview && (
        <>
          <h3>
            Parsed {preview.totals.structures} structures / {preview.totals.pieces} pieces
            {preview.job.name ? ` for "${preview.job.name}"` : ''}
          </h3>
          <p className="muted">
            Sheet "{preview.detected.sheet}", header row {preview.detected.headerRow}, BOM columns:{' '}
            {preview.detected.bomColumns.join(', ') || 'none detected'}
          </p>
          {preview.warnings.map((warning) => (
            <p className="error" key={warning}>
              {warning}
            </p>
          ))}
          <div className="scroll">
            <table>
              <thead>
                <tr>
                  <th>Structure</th>
                  <th>Station</th>
                  <th>Pieces</th>
                </tr>
              </thead>
              <tbody>
                {preview.structures.map((structure) => (
                  <tr key={structure.name}>
                    <td>{structure.name}</td>
                    <td>{structure.stationNumber}</td>
                    <td>{structure.pieces.map((piece) => piece.componentType).join(', ')}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p>
            <button type="button" className="primary" disabled={busy} onClick={runImport}>
              Push to Airtable
            </button>
          </p>
        </>
      )}

      {result && (
        <p className="notice">
          Imported into job "{result.job.name}" ({result.job.created ? 'new job' : 'existing job'}):{' '}
          {result.created.structures} structures, {result.created.pieces} pieces.
        </p>
      )}
    </section>
  );
}
