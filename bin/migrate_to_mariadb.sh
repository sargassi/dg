#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# dg: SQLite3 → MariaDB Production Migration Script
# ============================================================
# Run this on the production server after deploying the new code
# with mysql2 gem and updated database.yml.
#
# Usage: ssh deploy@okam.it
#        cd /home/deploy/dg/current
#        sudo bash bin/migrate_to_mariadb.sh
# ============================================================

RAILS_ENV="${RAILS_ENV:-production}"
DEPLOY_DIR="/home/deploy/dg"
SHARED_DIR="${DEPLOY_DIR}/shared"
CURRENT_DIR="${DEPLOY_DIR}/current"
BACKUP_DIR="${SHARED_DIR}/backups"
SQLITE_DB="${SHARED_DIR}/db/production.sqlite3"
MARIADB_DB="dg_production"
MARIADB_USER="deploy"
MARIADB_PASS="$(openssl rand -base64 24)"
MARIADB_HOST="localhost"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
DUMP_FILE="${BACKUP_DIR}/mariadb_${TIMESTAMP}.sql"
SQLITE_BACKUP="${BACKUP_DIR}/production_${TIMESTAMP}.sqlite3"

echo "=== dg: SQLite3 → MariaDB Migration ==="
echo "Started: $(date)"
echo ""

# ── Step 1: Backup ──────────────────────────────────────────
echo "[1/8] Backing up production SQLite3 database..."
mkdir -p "${BACKUP_DIR}"
cp "${SQLITE_DB}" "${SQLITE_BACKUP}"
echo "  ✔ Backed up to ${SQLITE_BACKUP}"

# ── Step 2: Install MariaDB ──────────────────────────────────
echo "[2/8] Checking/installing MariaDB..."
if ! command -v mysql &>/dev/null; then
  echo "  → Installing MariaDB server..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq mariadb-server mariadb-client
  sudo systemctl enable mariadb
  sudo systemctl start mariadb
  echo "  ✔ MariaDB installed ($(mysql --version))"
else
  echo "  ✔ MariaDB already installed ($(mysql --version))"
fi

# ── Step 3: Create database and user ─────────────────────────
echo "[3/8] Creating database and user..."
sudo mysql -e "
  CREATE DATABASE IF NOT EXISTS \`${MARIADB_DB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'localhost' IDENTIFIED BY '${MARIADB_PASS}';
  GRANT ALL PRIVILEGES ON \`${MARIADB_DB}\`.* TO '${MARIADB_USER}'@'localhost';
  FLUSH PRIVILEGES;
"
echo "  ✔ Database '${MARIADB_DB}' ready"
echo "  ✔ User '${MARIADB_USER}' created"

# Store password for Rails
mkdir -p "${SHARED_DIR}/config"
cat > "${SHARED_DIR}/config/database_password" <<-PASSEOF
${MARIADB_PASS}
PASSEOF
chmod 600 "${SHARED_DIR}/config/database_password"
echo "  ✔ Password stored in shared/config/database_password"

# ── Step 4: Fix schema.rb for MariaDB ────────────────────────
echo "[4/8] Fixing schema.rb for MariaDB compatibility..."
cd "${CURRENT_DIR}"
ruby -e '
schema = File.read("db/schema.rb")
schema.scan(/add_foreign_key "([^"]+)", "([^"]+)"(?:, column: "([^"]+)")?/) do |table, ref, col|
  fk_col = col || "#{ref.singularize}_id"
  schema.gsub!(/(create_table "#{table}"[^}]*?)(t\.integer "#{fk_col}")/) { "#{$1}#{$2.sub("t.integer", "t.bigint")}" }
end
schema.gsub!(/  add_foreign_key "prodrow", "prodcodes"\n/, "")
File.write("db/schema.rb", schema)
'
echo "  ✔ schema.rb fixed (FK columns → bigint, removed dangling FK)"

# ── Step 5: Load schema into MariaDB ─────────────────────────
echo "[5/8] Loading schema into MariaDB..."
DB_PASSWORD="${MARIADB_PASS}" bundle exec rails db:schema:load RAILS_ENV=production
echo "  ✔ Schema loaded"

# ── Step 6: Export data from SQLite3 and import ─────────────
echo "[6/8] Migrating data..."

# Export data using standalone script (must be copied to server or run inline)
ruby -e '
require "sqlite3"
db = SQLite3::Database.new("'"${SQLITE_DB}"'")
db.results_as_hash = true
tables = db.execute("SELECT name FROM sqlite_master WHERE type='"'table'"' ORDER BY name").map { |r| r["name"] }
tables -= ["schema_migrations", "ar_internal_metadata", "sqlite_sequence"]

File.open("'"${DUMP_FILE}"'", "w") do |f|
  f.puts "SET foreign_key_checks = 0;"
  f.puts "SET unique_checks = 0;"
  f.puts "SET sql_mode = "'"'"ALLOW_INVALID_DATES"'"'";"
  f.puts ""
  tables.each do |table|
    col_info = db.execute("PRAGMA table_info(\"#{table}\")")
    col_names = col_info.map { |c| c["name"] }
    rows = db.execute("SELECT * FROM \"#{table}\"")
    next if rows.empty?
    f.puts "LOCK TABLES `#{table}` WRITE;"
    f.puts ""
    rows.each do |row|
      values = col_names.map do |c|
        v = row[c]
        if v.nil? then "NULL"
        elsif v.is_a?(Integer) || v.is_a?(Float) then v.to_s
        else "'"'"#{v.to_s.gsub("'", "'"''"'")}"'"'"
        end
      end
      f.puts "INSERT INTO `#{table}` (`#{col_names.join("'"'`, `"'"'")}`) VALUES (#{values.join("'"', '"'")});"
    end
    f.puts ""
    f.puts "UNLOCK TABLES;"
    f.puts ""
  end
  f.puts "SET foreign_key_checks = 1;"
  f.puts "SET unique_checks = 1;"
end
'

echo "  ✔ Data exported to ${DUMP_FILE}"

# Import
mysql -h "${MARIADB_HOST}" -u "${MARIADB_USER}" -p"${MARIADB_PASS}" "${MARIADB_DB}" < "${DUMP_FILE}"
echo "  ✔ Data imported into MariaDB"

# ── Step 7: Verify ──────────────────────────────────────────
echo "[7/8] Verifying row counts..."

# Compare every table between SQLite and MariaDB
MISMATCH=0
while IFS= read -r table; do
  sqlite_val=$(sqlite3 "${SQLITE_DB}" "SELECT COUNT(*) FROM \"${table}\";")
  mariadb_val=$(mysql -h "${MARIADB_HOST}" -u "${MARIADB_USER}" -p"${MARIADB_PASS}" "${MARIADB_DB}" -N -e "SELECT COUNT(*) FROM \`${table}\`;" 2>/dev/null)
  if [ "${sqlite_val}" = "${mariadb_val}" ]; then
    echo "  ✔ ${table}: ${sqlite_val} rows"
  else
    echo "  ✗ ${table}: ${sqlite_val} (SQLite) vs ${mariadb_val} (MariaDB) — MISMATCH!"
    MISMATCH=1
  fi
done < <(sqlite3 "${SQLITE_DB}" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" | grep -v "^schema_migrations$\|^ar_internal_metadata$\|^sqlite_sequence$")

if [ "${MISMATCH}" = "1" ]; then
  echo ""
  echo "⚠️  Row count mismatches found! Check the export/import."
  echo "   SQLite backup preserved at: ${SQLITE_BACKUP}"
  echo "   Data dump preserved at: ${DUMP_FILE}"
  exit 1
fi

echo "  ✔ All row counts match!"

# ── Step 8: Switch config and restart ──────────────────────
echo "[8/8] Updating database.yml and restarting Passenger..."

cat > "${CURRENT_DIR}/config/database.yml" <<-YMLEOF
production:
  adapter: mysql2
  encoding: utf8mb4
  database: ${MARIADB_DB}
  host: ${MARIADB_HOST}
  port: 3306
  username: ${MARIADB_USER}
  password: <%= File.read(Rails.root.join('..', '..', 'shared', 'config', 'database_password')).strip %>
  pool: 10
YMLEOF

echo "  ✔ database.yml updated"

# Restart Passenger
passenger-config restart-app "${CURRENT_DIR}" || sudo passenger-config restart-app "${CURRENT_DIR}" || true
echo "  ✔ Passenger restarted"

# ── Done ────────────────────────────────────────────────────
echo ""
echo "=== Migration complete! ==="
echo "SQLite3 backup: ${SQLITE_BACKUP}"
echo ""
echo "Verification steps:"
echo "  1. Access the app and verify functionality"
echo "  2. Check logs: journalctl -u nginx -f (or tail -f log/production.log)"
echo "  3. After confirming everything works:"
echo "     - Deploy new code with updated Capistrano config (remove linked sqlite3 file)"
echo "     - After 1 week stability, remove sqlite3 gem from Gemfile"
echo ""
echo "Rollback if needed:"
echo "  cp ${SQLITE_BACKUP} ${SHARED_DIR}/db/production.sqlite3"
echo "  # Restore old database.yml with sqlite3 config"
echo "  passenger-config restart-app ${CURRENT_DIR}"
