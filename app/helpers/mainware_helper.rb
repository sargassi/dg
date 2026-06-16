module MainwareHelper
  def mainware_menu(active:)
    [
      { label: 'Dashboard',      path: mainware_dashboard_path,      active: active == 'dashboard',       icon: 'dashboard',       can: 'manage_mainware' },
      { label: 'Articoli',       path: mainware_index_path,          active: active == 'articoli',        icon: 'inventory_2',     can: 'manage_mainware' },
      { label: 'Nuovo articolo', path: new_item_path,                active: active == 'nuovo_articolo',  icon: 'add_circle',       can: 'manage_mainware' },
      { label: 'Ricerca QR',     path: mainware_searchqr_path,      active: active == 'ricerca_qr',      icon: 'qr_code_scanner', can: 'manage_mainware' },
      { label: 'Storico Prezzi', path: mainware_prices_compare_path, active: active == 'storico_prezzi',   icon: 'payments',        can: 'manage_mainware' },
      { label: 'Collezioni',     path: collections_path,              active: active == 'collezioni',      icon: 'collections_bookmark', can: 'manage_collections' },
    ]
  end
end
