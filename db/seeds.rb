abilities = [
  { name: 'manage_proformas',     description: 'Crea/modifica/elimina ordini di produzione', category: 'production' },
  { name: 'view_production',      description: 'Visualizza dashboard di produzione e ricerca', category: 'production' },
  { name: 'checkpoint_scan',      description: 'Scansione QR code ai checkpoint di produzione', category: 'production' },
  { name: 'print_labels_proforma', description: 'Stampa etichette proforma', category: 'labels' },
  { name: 'print_labels_lab',     description: 'Stampa etichette laboratorio', category: 'labels' },
  { name: 'print_labels_camp',    description: 'Stampa etichette campionario', category: 'labels' },
  { name: 'print_labels_gen',     description: 'Stampa etichette generiche', category: 'labels' },
  { name: 'manage_items',         description: 'Crea/modifica/elimina articoli', category: 'warehouse' },
  { name: 'manage_warehouse',     description: 'Gestione magazzini/ubicazioni', category: 'warehouse' },
  { name: 'manage_inventory',     description: 'Movimenti di magazzino (carichi/scarichi)', category: 'warehouse' },
  { name: 'import_data',          description: 'Importa dati CSV/XLS', category: 'data' },
  { name: 'manage_users',         description: 'Gestione utenti e assegnazione abilitazioni', category: 'admin' },
  { name: 'manage_events',        description: 'Crea/modifica eventi', category: 'admin' },
  { name: 'view_reports',         description: 'Visualizza report produzione/magazzino', category: 'reports' },
]

abilities.each do |attrs|
  Ability.find_or_create_by!(name: attrs[:name]) do |a|
    a.description = attrs[:description]
    a.category     = attrs[:category]
  end
end
