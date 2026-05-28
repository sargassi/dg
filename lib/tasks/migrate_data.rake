namespace :db do
  desc "Dump SQLite3 data to a MySQL-compatible SQL file"
  task dump_for_mysql: :environment do
    raise "Only run with SQLite3 adapter" unless ActiveRecord::Base.connection.adapter_name == "SQLite3"

    tables = ActiveRecord::Base.connection.tables - ["schema_migrations", "ar_internal_metadata", "sqlite_sequence"]
    output_path = Rails.root.join("tmp/mysql_import.sql")

    File.open(output_path, "w") do |f|
      f.puts "-- Data export from SQLite3 for MariaDB import"
      f.puts "-- Generated: #{Time.current}"
      f.puts
      f.puts "SET foreign_key_checks = 0;"
      f.puts "SET unique_checks = 0;"
      f.puts "SET sql_mode = 'ALLOW_INVALID_DATES';"
      f.puts

      tables.each do |table|
        columns = ActiveRecord::Base.connection.columns(table)
        col_names = columns.map(&:name)

        rows = ActiveRecord::Base.connection.select_all("SELECT * FROM #{table}")

        next if rows.empty?

        f.puts "LOCK TABLES `#{table}` WRITE;"
        f.puts

        rows.each do |row|
          values = col_names.map do |c|
            v = row[c]
            if v.nil?
              "NULL"
            elsif v.is_a?(Integer) || v.is_a?(Float)
              v.to_s
            elsif v.is_a?(BigDecimal)
              v.to_s("F")
            else
              ActiveRecord::Base.connection.quote(v)
            end
          end
          f.puts "INSERT INTO `#{table}` (`#{col_names.join('`, `')}`) VALUES (#{values.join(', ')});"
        end

        f.puts
        f.puts "UNLOCK TABLES;"
        f.puts
      end

      f.puts "SET foreign_key_checks = 1;"
      f.puts "SET unique_checks = 1;"
    end

    puts "Data exported to #{output_path}"
    puts "Import with: mysql -h <host> -u <user> -p <database> < #{output_path}"
  end
end
