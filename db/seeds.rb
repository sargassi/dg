# ── Abilitazioni ──────────────────────────────────────────────────────────
# Ogni riga è una sezione dell'app che può essere concessa o negata a un utente.
# Categoria → raggruppamento logico nella UI di admin/users.
# Il campo `name` viene usato in `User#can?(name)` e nei `before_action` dei controller.
ABILITIES = [
  # ── Proformas ─────────────────────────────────────────────────────────
  { name: 'manage_proformas',     description: 'Crea/modifica/elimina ordini di produzione',        category: 'Proformas' },

  # ── Production ────────────────────────────────────────────────────────
  { name: 'view_production',      description: 'Dashboard produzione e ricerca',                    category: 'Production' },
  { name: 'checkpoint_scan',      description: 'Scansione QR ai checkpoint di produzione',          category: 'Production' },
  { name: 'manage_prows',         description: 'Gestione righe di produzione (prows)',              category: 'Production' },
  { name: 'manage_tempesta',      description: 'Gestione checkpoint unitari (tempesta)',            category: 'Production' },
  { name: 'manage_stages',        description: 'Visualizzazione fasi produzione',                   category: 'Production' },
  { name: 'manage_stations',      description: 'Gestione postazioni di lavoro',                     category: 'Production' },
  { name: 'manage_rails',         description: 'Gestione binari/rastrelliere produzione',           category: 'Production' },

  # ── Utilities / Etichette ─────────────────────────────────────────────
  { name: 'print_labels_proforma', description: 'Stampa etichette proforma',                        category: 'Utilities' },
  { name: 'print_labels_lab',     description: 'Stampa etichette laboratorio',                      category: 'Utilities' },
  { name: 'print_labels_camp',    description: 'Stampa etichette campionario',                      category: 'Utilities' },
  { name: 'print_labels_gen',     description: 'Stampa etichette generiche',                        category: 'Utilities' },
  { name: 'print_labels_check',   description: 'Stampa etichette controllo/lavaggio',               category: 'Utilities' },
  { name: 'manage_utilities_labels', description: 'Dashboard utility etichette',                    category: 'Utilities' },
  { name: 'manage_basic_qr_codes', description: 'Lettore QR code base',                            category: 'Utilities' },
  { name: 'manage_app_sectors',   description: 'Scansione QR per settori (app)',                   category: 'Utilities' },

  # ── Etichecks ─────────────────────────────────────────────────────────
  { name: 'manage_etichecks',     description: 'Gestione etichette controllo (etichecks)',          category: 'Etichecks' },
  { name: 'manage_eticamps',      description: 'Gestione etichette campionario (eticamps)',         category: 'Eticamps' },
  { name: 'manage_etigens',       description: 'Gestione etichette generiche (etigens)',            category: 'EtiGens' },
  { name: 'manage_etilabs',       description: 'Gestione etichette laboratorio (etilabs)',          category: 'EtiLabs' },
  { name: 'manage_fabriclus',     description: 'Gestione tessuti/fornitori (fabriclus)',            category: 'Fabriclus' },

  # ── Items ─────────────────────────────────────────────────────────────
  { name: 'manage_items',         description: 'Crea/modifica/elimina articoli di magazzino',       category: 'Items' },
  { name: 'manage_inventory',     description: 'Giacenze / inventario',                             category: 'Inventories' },
  { name: 'manage_itemins',       description: 'Registrazione carichi (itemins)',                   category: 'Itemins' },
  { name: 'manage_itemouts',      description: 'Registrazione scarichi (itemouts)',                 category: 'Itemouts' },
  { name: 'manage_warehouses',    description: 'Gestione anagrafica magazzini',                     category: 'Warehouses' },
  { name: 'manage_locations',     description: 'Gestione ubicazioni',                              category: 'Locations' },
  { name: 'manage_operationtypes', description: 'Gestione tipi movimentazione',                     category: 'Operationtypes' },
  { name: 'manage_mainware',      description: 'Browser articoli (mainware)',                       category: 'Mainware' },

  # ── Collections ───────────────────────────────────────────────────────
  { name: 'manage_collections',   description: 'Gestione collezioni',                              category: 'Collections' },
  { name: 'manage_areas',         description: 'Gestione aree',                                    category: 'Areas' },
  { name: 'manage_uoms',          description: 'Gestione unità di misura',                         category: 'Uoms' },
  { name: 'manage_taglia',        description: 'Gestione taglie',                                  category: 'Taglia' },
  { name: 'manage_products',      description: 'Gestione prodotti',                                category: 'Products' },

  # ── ProductsImports ───────────────────────────────────────────────────
  { name: 'manage_products_imports', description: 'Importazione prodotti da Excel',                category: 'ProductsImports' },
  { name: 'import_data',          description: 'Importa dati CSV/XLS',                             category: 'Data' },
  { name: 'manage_rassegnas',     description: 'Gestione rassegna stampa',                         category: 'Rassegnas' },

  # ── Directory ─────────────────────────────────────────────────────────
  { name: 'manage_directory',     description: 'Rubrica utenti (directory)',                       category: 'Directory' },
  { name: 'manage_events_calendar', description: 'Gestione calendario eventi',                     category: 'Directory::Events' },

  # ── Admin ─────────────────────────────────────────────────────────────
  { name: 'manage_users',         description: 'Gestione utenti e abilitazioni',                   category: 'Admin::Users' },
  { name: 'manage_events',        description: 'Crea/modifica eventi',                             category: 'Events' },
  { name: 'manage_eventypes',     description: 'Gestione tipi evento',                             category: 'Eventypes' },

  # ── Reports ───────────────────────────────────────────────────────────
  { name: 'view_reports',         description: 'Report produzione/magazzino',                      category: 'Reports' },
]

ABILITIES.each do |attrs|
  a = Ability.find_or_initialize_by(name: attrs[:name])
  a.update!(description: attrs[:description], category: attrs[:category])
end

# ── Eventypes ─────────────────────────────────────────────────────────────
%w[Compleanno].each do |name|
  Eventype.find_or_create_by!(name: name) do |e|
    e.enabled = true
    e.color = "#EC4899"
  end
end
