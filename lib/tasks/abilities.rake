namespace :abilities do
  desc "Scansiona i controller e segnala eventuali sezioni senza abilitazione corrispondente"
  task check_missing: :environment do
    # Mappa: nome controller → candidate ability name
    # Regola di default: ControllerName → manage_controller_names
    # Eccezioni note (controller che non hanno senso come abilitazione)
    SKIP = %w[
      application_controller app_controller
      dashboard_controller
      production_controller
      directory_controller
      utilities_controller
      mainware_controller
    ].freeze

    # Casi speciali: alcuni controller usano un nome ability diverso dal default
    OVERRIDES = {
      'admin/users_controller'           => 'manage_users',
      'directory/events_controller'      => 'manage_events_calendar',
      'production/proformas_controller'  => 'manage_proformas',
      'inventories_controller'           => 'manage_inventory',
      'warehouses_controller'            => 'manage_warehouses',
      'locations_controller'             => 'manage_locations',
      'collections_controller'           => 'manage_collections',
      'areas_controller'                 => 'manage_areas',
      'stations_controller'              => 'manage_stations',
      'uoms_controller'                  => 'manage_uoms',
      'eventypes_controller'             => 'manage_eventypes',
      'operationtypes_controller'        => 'manage_operationtypes',
      'taglia_controller'                => 'manage_taglia',
      'rails_controller'                 => 'manage_rails',
      'rassegnas_controller'             => 'manage_rassegnas',
      'fabriclus_controller'             => 'manage_fabriclus',
      'products_controller'              => 'manage_products',
      'products_imports_controller'      => 'manage_products_imports',
      'items_controller'                 => 'manage_items',
      'itemins_controller'               => 'manage_itemins',
      'itemouts_controller'              => 'manage_itemouts',
      'etichecks_controller'             => 'manage_etichecks',
      'eticamps_controller'              => 'manage_eticamps',
      'etigens_controller'               => 'manage_etigens',
      'etilabs_controller'               => 'manage_etilabs',
      'prows_controller'                 => 'manage_prows',
      'tempesta_controller'              => 'manage_tempesta',
      'stages_controller'                => 'manage_stages',
      'basic_qr_codes_controller'        => 'manage_basic_qr_codes',
    }.freeze

    # Raccogli tutti i file controller
    controller_dir = Rails.root.join('app', 'controllers')
    controllers = Dir.glob("#{controller_dir}/**/*_controller.rb").map do |path|
      Pathname.new(path).relative_path_from(controller_dir).sub_ext('').to_s
    end

    existing = Ability.pluck(:name).to_set

    missing = []

    controllers.each do |ctrl|
      next if SKIP.include?(ctrl)

      candidate = OVERRIDES[ctrl] || "manage_#{ctrl.tr('/', '_').delete_suffix('_controller')}"

      unless existing.include?(candidate)
        # Prova a indovinare descrizione e categoria
        label = ctrl.delete_suffix('_controller').tr('_', ' ').titleize
        missing << { name: candidate, controller: ctrl, label: label }
      end
    end

    if missing.any?
      puts "\n⚠️  Abilitazioni mancanti (#{missing.size}):\n\n"
      missing.each do |m|
        puts "  #{m[:name].ljust(35)} ← #{m[:controller]}"
      end
      puts "\nPer aggiungerle, inserisci in db/seeds.rb:\n\n"
      missing.each do |m|
        puts "  { name: '#{m[:name]}', description: 'TODO - #{m[:label]}', category: 'TODO' },"
      end
    else
      puts "\n✅ Tutti i controller hanno un'abilitazione corrispondente.\n"
    end
  end
end
