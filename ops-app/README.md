# Precast Operations web app

Node/Express backend + React (Vite) frontend for the "Precast Operations Master" Airtable base.

## Setup

```bash
cd ops-app/backend && npm install
cp .env.example .env   # paste AIRTABLE_PERSONAL_ACCESS_TOKEN
cd ../frontend && npm install
```

Run both (two terminals):

```bash
cd ops-app/backend && npm run dev     # http://localhost:4000
cd ops-app/frontend && npm run dev    # http://localhost:5173 (proxies /api)
```

## Features

1. **MH Pro order-summary intake** — drag an MH Pro export onto the dashboard. Both serializations
   are supported: native `.xlsx` and MH Pro's "Excel XML" (SpreadsheetML `.xml`) export
   (`backend/src/excel/readGrid.js` normalizes both into a row grid). The parser
   (`backend/src/excel/parseMhPro.js`) reads job name + contractor from the preamble, locates the
   line-item header row by synonym match (`Structure Name` / `Description` / `Quantity` / ...),
   skips `Total Weight (lbs)` separator rows, groups line items by structure, expands each line by
   its `Quantity`, and classifies descriptions into `Base` / `Riser` / `Top` / `Casting` /
   `Accessory` (`columnMap.js`). Preview first, then push to `Jobs`, `Structures`, and
   `Pieces & Castings` with Production Status `Not Started` and Shipping Status mapped from the
   sheet's `Status` column when present (`OWED` → `Owed`, `SHIPPED` → `Shipped`), else `Pending`.
   Each line item's `Part Weight` lands in the pieces table's `Weight (lbs)` column. Imports only
   write fields that exist in the live base, matched case-insensitively (`pickExistingFields`), so a
   base spelling like `Weight (LBS)` still works.
2. **Batch production planner** — lists `Not Started` / `Scheduled` structures across all jobs,
   multi-select with checkboxes, pick a date, bulk-set `Target Production Date` + status `Scheduled`.
3. **Dispatch & truck loads** — create a load (auto Load ID `LD-YYYYMMDD-NNN`, status `Building`),
   then select ready pieces across jobs and assign them: sets `Assigned Truck Load` and Shipping
   Status `Loaded`. A sticky footer tallies the selected pieces' `Weight (lbs)` live against an
   editable limit (default 48,000 lbs) and turns red once the load exceeds it.

## Base schema notes

The live base differs slightly from the original spec:

- Structures `Production Status` options are `Not Started`, `Scheduled`, `Poured` (no
  "Poured/Stripped"), and pour state is tracked on the structure, not the piece.
- Pieces `Shipping Status` options are `Pending`, `Loaded`, `Shipped`, `Owed` (no
  "Owed/Backordered").

So "ready to ship" = pieces whose parent structure is `Poured` and whose shipping status is
`Pending` or `Owed`.

## API

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/api/health` | config check |
| POST | `/api/intake/preview` | parse an .xlsx/.xml export without writing |
| POST | `/api/intake/import` | parse + create Airtable records |
| GET | `/api/structures` | plannable structures |
| POST | `/api/structures/schedule` | bulk set target date + `Scheduled` |
| GET | `/api/truck-loads` | list loads |
| POST | `/api/truck-loads` | create load with generated ticket # |
| GET | `/api/pieces/shippable` | pieces ready to load |
| POST | `/api/truck-loads/:id/assign` | assign pieces to a load |
