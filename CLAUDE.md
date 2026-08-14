# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A dbt + DuckDB analytics pipeline that transforms raw NYC TLC yellow-taxi trip records
(monthly Parquet files) into a tested star schema. No cloud warehouse — DuckDB reads the
Parquet files directly as a source, no load step. Built as a learning project by someone
coming from Airflow/SQL pipeline work, so the design favors "production-shaped" patterns
(incremental builds, layered models, data-quality tests) over shortcuts.

Stack: dbt Core 1.11, dbt-duckdb 1.10.1, DuckDB, Python 3.12 (venv at `.venv/`).

## Setup & commands

```bash
python3 -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

dbt profile is named `nyc_taxi` (see `dbt_project.yml`); it must exist in `~/.dbt/profiles.yml`
pointing at a local DuckDB file (type `duckdb`, `path: './dev.duckdb'`). That file is not
part of this repo.

Common commands (run from repo root, venv activated):

```bash
dbt build                      # seeds + models + tests, full pipeline
dbt run                        # models only, no tests
dbt test                       # tests only
dbt run --select stg_trips     # single model
dbt run --select +fct_trips    # a model and everything upstream of it
dbt test --select fct_trips    # tests for one model
dbt seed                       # load seeds/*.csv (taxi_zone_lookup, vendor)
dbt docs generate && dbt docs serve   # lineage graph + column docs
dbt run --full-refresh --select fct_trips   # rebuild all microbatches from scratch
```

Raw Parquet files live in `data/raw/` (git-ignored — must be downloaded manually from the
NYC TLC site before a run) and `dev.duckdb` is also git-ignored, so a fresh clone has
neither data nor a built database.

## Architecture

```
sources (Parquet, data/raw/*.parquet)
  → staging (stg_trips)             — 1:1 rename/cast/decode, no joins or filtering
  → intermediate (int_trips_joined_to_vendors) — joins + data-quality filters
  → marts
      dim_zones      (from taxi_zone_lookup seed)
      fct_trips       (incremental microbatch fact)
      agg_per_zone    (aggregated from fct_trips + dim_zones)
```

Layer discipline is deliberate and matters when adding models: staging never joins or
filters rows — only intermediate does. Row-level data-quality filters (e.g. `dropoff_datetime
>= pickup_datetime`) belong in intermediate, not staging or marts.

### Key design decisions (don't relitigate without reason)

- **Star schema, role-playing dimension.** `fct_trips` joins `dim_zones` for both pickup
  and dropoff location. Vendor, rate code, and payment type are decoded to text in staging
  (`stg_trips`) as enums, not modeled as separate dimension tables — they're small
  code→label lookups that don't earn their own table.
- **No natural primary key.** TLC trip data has no trip id. Idempotency is handled at the
  **month** grain (microbatch), not via a synthetic/surrogate row key.
- **Seeds vs sources.** `taxi_zone_lookup` and `vendor` are seeds (checked-in CSVs in
  `seeds/`), not sources, because they're small, slow-changing, version-controlled lookup
  data — not raw event data. Trip data is a source because it's the large raw feed.
- **`fct_trips` is incremental microbatch**, config in `models/marts/fct_trips.sql`:
  `event_time='pickup_datetime'`, `batch_size='month'`, `lookback=5`, `full_refresh=false`.
  Each month is its own batch, rebuilt atomically. The lookback absorbs TLC's ~2-month
  publication lag and month-level restatements — this is why there's no `is_incremental()`
  high-watermark filter anywhere in the project.
- **Test severity is a judgment call, not uniform.** `fare_amount` non-negativity is
  `severity: warn` (negative fares are legitimate TLC refunds/disputes, ~115k rows);
  `trip_duration_min` non-negativity is `error` (a trip can never end before it starts).
  Follow this pattern — decide severity per-column based on whether the data condition is
  a real invariant or an expected/monitored anomaly, don't default everything to `error`.
- **Source-boundary tests.** `accepted_values` on raw `RatecodeID`/`payment_type` are
  tested at the source (`models/staging/_nyc_taxi__sources.yml`), before they get decoded
  into text in staging — catches bad codes before they silently produce `NULL` labels.

### Macros

- `non_negative` (`tests/generic/non_negative.sql`) — custom generic test, applied to
  durations/distances/fares across models rather than repeating `WHERE x < 0` singular tests.
- `safe_divide(numerator, denominator)` — division with `NULLIF` guard against divide-by-zero.
- `trip_metrics()` — shared block of aggregate SELECT columns (trip_count, avg duration,
  total revenue, avg distance/fare, tip % via `safe_divide`), used by aggregate marts like
  `agg_per_zone` so metric definitions aren't duplicated per mart.
- `log_run_results(results)` — wired into `on-run-end` in `dbt_project.yml`; writes each
  run's node-level status/timing/rows-affected into `main.dbt_run_results` for observability.
  If you add new run hooks, be aware this one already runs on every `dbt build`/`dbt run`.

## Testing conventions

- Add generic tests (`not_null`, `unique`, `accepted_values`, `relationships`,
  `non_negative`) in the model's `_<layer>.yml` file next to the model, not inline in `.sql`.
- Use the custom `non_negative` generic test for any new non-negative numeric column instead
  of writing a new singular test.
- Singular tests go in `tests/` (e.g. `neg_duration.sql`); generic/reusable test macros go
  in `tests/generic/`.
- Referential integrity between fact and dimension tables uses `relationships` tests
  (see `fct_trips` → `dim_zones` in `models/marts/_marts.yml`), not manual anti-join checks.
