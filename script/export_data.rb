#!/usr/bin/env ruby
require "sqlite3"

db_path = ARGV[0] || "db/development.sqlite3"
output_path = ARGV[1] || "tmp/mysql_import.sql"

db = SQLite3::Database.new(db_path)
db.results_as_hash = true

tables = db.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").map { |r| r["name"] }
tables -= ["schema_migrations", "ar_internal_metadata", "sqlite_sequence"]

File.open(output_path, "w") do |f|
  f.puts "-- Data export from SQLite3 for MariaDB import"
  f.puts "-- Generated: #{Time.now}"
  f.puts ""
  f.puts "SET foreign_key_checks = 0;"
  f.puts "SET unique_checks = 0;"
  f.puts "SET sql_mode = 'ALLOW_INVALID_DATES';"
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
        if v.nil?
          "NULL"
        elsif v.is_a?(Integer) || v.is_a?(Float)
          v.to_s
        else
          escaped = v.to_s.gsub("'", "''")
          "'#{escaped}'"
        end
      end
      f.puts "INSERT INTO `#{table}` (`#{col_names.join('`, `')}`) VALUES (#{values.join(', ')});"
    end

    f.puts ""
    f.puts "UNLOCK TABLES;"
    f.puts ""
  end

  f.puts "SET foreign_key_checks = 1;"
  f.puts "SET unique_checks = 1;"
end

puts "Data exported to #{output_path}"
puts "Import with: mysql -h <host> -u <user> -p <database> < #{output_path}"
