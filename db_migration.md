# SQLite3 → MariaDB Migration: dg

Migrating from SQLite3 to MariaDB for both development and production environments.

## Overview

| Metric | Value |
|--------|-------|
| Tables | ~35 (incl. Active Storage + Action Text) |
| Complexity | Medium (no Docker/MariaDB on server yet) |
| Dev work | ~1 session |
| Prod work | ~30 min maintenance window |
| Downtime | Yes — app read-only during data transfer (~5-10 min) |

---

## Phase 0: Pre-Flight — Row Count Baseline

Before any changes, save row counts from every table to verify later:

```bash
# Development
sqlite3 db/development.sqlite3 ".tables" | tr ' ' '\n' | while read t; do
  echo "$t: $(sqlite3 db/development.sqlite3 \"SELECT COUNT(*) FROM '$t';\")"
done > tmp/sqlite3_dev_counts.txt

# Production (via SSH)
ssh deploy@79.137.27.165 "
  cd /home/deploy/dg/current
  sqlite3 ../shared/db/production.sqlite3 '.tables' | tr ' ' '\n' | while read t; do
    echo \"\$t: \$(sqlite3 ../shared/db/production.sqlite3 \\\"SELECT COUNT(*) FROM '\$t';\\\")\"
  done
" > tmp/sqlite3_prod_counts.txt
```

---

## Phase 1: Code Preparation

### 1.1 — Gemfile

Gemfile:
- Move `sqlite3` to `:development, :test` group
- Add `mysql2` to default group

### 1.2 — Docker Compose (Development)

`docker-compose.yml` at project root:
- MariaDB 10.11 (LTS until 2028)
- Port 3306, named volume for persistence
- utf8mb4 charset, UTC timezone
- Database `dg_development`, user `dg_dev`

### 1.3 — Database Configuration

`config/database.yml`:
- Development: MariaDB via `mysql2` adapter (connects to Docker at `127.0.0.1:3306`)
- Test: stays on SQLite3 (unchanged for now)
- Production: MariaDB via `mysql2` adapter (connects to `localhost:3306`)
- Credentials via environment variables (`DB_USERNAME`, `DB_PASSWORD`, `DB_HOST`)

### 1.4 — Start Local MariaDB

```bash
docker compose up -d
```

---

## Phase 2: Data Migration Strategy

### Type Mapping

| SQLite3 | MariaDB | Notes |
|---------|---------|-------|
| `INTEGER` | `INT AUTO_INCREMENT` | Rails handles via schema |
| `BOOLEAN` (0/1) | `TINYINT(1)` | ActiveRecord transparent |
| `DATETIME` | `DATETIME` | No precision change needed |
| `FLOAT` | `DOUBLE` | Direct |
| `DECIMAL` | `DECIMAL` | Direct |
| `TEXT` | `TEXT` | Direct |
| `VARCHAR` | `VARCHAR(255)` | Rails default |

### Schema Loading

```bash
bin/rails db:schema:load
```

Rails handles adapter differences automatically. The generated `schema.rb` maps column types correctly for MariaDB.

### Data Export (Rake Task)

A custom rake task exports data row-by-row using ActiveRecord's quoting and type coercion — safer than raw `.dump`. Outputs a MySQL-compatible SQL file with:

- `SET foreign_key_checks = 0` / `SET unique_checks = 0` for fast import
- `LOCK TABLES` / `UNLOCK TABLES` per table
- Explicit `id` values to preserve auto-increment sequences
- Rails `.quote()` for proper escaping

### Data Import

```bash
mysql -h 127.0.0.1 -u dg_dev -p dg_development < tmp/mysql_import.sql
```

---

## Phase 3: Local Migration Steps

```bash
# 1. Add mysql2 gem to Gemfile, move sqlite3 to dev/test
# 2. Create docker-compose.yml
# 3. Start MariaDB
docker compose up -d
# 4. Update config/database.yml
# 5. Install gems
bundle install
# 6. Create DB + load schema
bin/rails db:create
bin/rails db:schema:load
# 7. Export SQLite3 data
bin/rails db:dump_for_mysql
# 8. Import into MariaDB
mysql -h 127.0.0.1 -u dg_dev -p dg_development < tmp/mysql_import.sql
# 9. Verify & smoke test
bin/rails runner "puts User.count"
bin/rails server -p 3000
```

### Verification

```bash
# Compare row counts
diff tmp/sqlite3_dev_counts.txt <(bin/rails runner "puts ActiveRecord::Base.connection.tables.sort.map { |t| \"#{t}: #{ActiveRecord::Base.connection.select_value(\"SELECT COUNT(*) FROM #{t}\")}\" }")

# Check schema_migrations
bin/rails runner "pp ActiveRecord::Base.connection.migration_context.get_all_versions"
```

---

## Phase 4: Production Migration Script

### `bin/migrate_to_mariadb.sh`

Idempotent safe script executed on the production server:

1. **Backup** — copies SQLite3 DB to `/home/deploy/dg/shared/backups/` with timestamp
2. **Install MariaDB** — `apt-get install mariadb-server mariadb-client` (skips if present)
3. **Create DB + user** — `dg_production` database, random password, localhost only
4. **Load schema** — `bin/rails db:schema:load RAILS_ENV=production`
5. **Export & import data** — row-by-row via Rails runner piped to `mysql` CLI
6. **Verify** — row count comparison for every table (fail on mismatch)
7. **Update database.yml** — writes production config with env-var-based password
8. **Restart** — `passenger-config restart-app`

### Rollback Strategy

| Scenario | Action |
|----------|--------|
| MariaDB install fails | App stays on SQLite3. Fix and retry. |
| Data import fails mid-way | `DROP DATABASE dg_production`, recreate, fix script, retry. App still on SQLite3. |
| App fails on MariaDB | Restore `database.yml` to sqlite3 config, restart Passenger. SQLite3 backup intact. |
| Full rollback | `cp backup.sqlite3 shared/db/production.sqlite3`, revert database.yml, restart Passenger. |

---

## Phase 5: Capistrano Changes

After migration is stable (1 week):

- Remove `db/production.sqlite3` from `linked_files` in `config/deploy.rb`
- Remove the custom `ensure_db_file` hook
- Password stored in environment (server ENV or `.rbenv-vars`), not in repo

---

## Phase 6: Cleanup & Post-Migration

After 1 week of stability:

1. Remove `sqlite3` gem entirely from Gemfile
2. Delete `db/production.sqlite3` from shared directory
3. Archive/remove backup SQLite dumps
4. Remove `linked_files` entries for sqlite3 in deploy.rb
5. Tune MariaDB: `innodb_buffer_pool_size`, `max_connections`
6. Add MariaDB monitoring to health checks
7. Migrate test environment to MariaDB (optional)

---

## Potential Pitfalls

| Issue | Severity | Mitigation |
|-------|----------|------------|
| `force: :cascade` in schema.rb | None | Rails mysql2 adapter ignores cascade, just does `DROP TABLE IF EXISTS` |
| Booleans as 0/1 | None | ActiveRecord handles transparently |
| Table name case sensitivity | ⚠️ Medium | Set `lower_case_table_names=1` in MariaDB config (SQLite is case-insensitive, MariaDB on Linux isn't) |
| `datetime` precision | None | Rails defaults are second-precision for both adapters |
| Migration SQLite-specific syntax | None | Running migrations against MariaDB after switch — old migrations already applied |

### Critical: Case Sensitivity

Add to `/etc/mysql/mariadb.conf.d/50-server.cnf`:

```ini
[mysqld]
lower_case_table_names=1
```

---

## Timeline

| Step | Duration | Downtime |
|------|----------|----------|
| Phase 1: Code prep | ~15 min | None |
| Phase 1: Docker + local MariaDB | ~10 min | None |
| Phase 2: Data migration dev | ~5 min | None |
| Phase 3: Verify locally | ~10 min | None |
| Phase 4: Production migration | ~15-30 min | ~5-10 min during data import |
| Phase 5: Capistrano cleanup | ~10 min | None |
| Phase 6: Observability | 1 week | None |

**Total hands-on: ~1.5-2 hours**
**Production read-only window: ~10 minutes**
