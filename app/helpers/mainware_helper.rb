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

  def mainware_section_toolbar(skip_config: false)
    items = [
      { label: 'Dashboard',      path: mainware_dashboard_path,      icon: 'dashboard',       can: 'manage_mainware',      group: :nav },
      { label: 'Articoli',       path: mainware_index_path,          icon: 'inventory_2',     can: 'manage_mainware',      group: :nav },
      { label: 'Ricerca QR',     path: mainware_searchqr_path,      icon: 'qr_code_scanner', can: 'manage_mainware',      group: :nav },
      { label: 'Storico Prezzi', path: mainware_prices_compare_path, icon: 'payments',        can: 'manage_mainware',      group: :nav },
      { label: 'Nuovo',          path: new_item_path,                icon: 'add_circle',      can: 'manage_mainware',      group: :actions, type: :action },
      { label: 'Import',         path: mainware_import_path,         icon: 'file_upload',     can: 'manage_mainware',      group: :actions, type: :action },
      { label: 'Collezioni',     path: collections_path,             icon: 'collections_bookmark', can: 'manage_collections', group: :admin },
    ]
    items = items.select { |i| i[:can].nil? || current_user.can?(i[:can]) }
    return items if skip_config
    ToolbarConfig.filter_items(:mainware, items)
  end
end
