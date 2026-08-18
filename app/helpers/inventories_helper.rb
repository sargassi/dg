module InventoriesHelper
  def inventories_section_toolbar(skip_config: false)
    items = [
      { label: 'Dashboard', path: inventories_dashboard_path,                icon: 'dashboard',      can: 'manage_inventory',  group: :nav },
      { label: 'Ricerca',   path: inventories_path,                          icon: 'inventory_2',    can: 'manage_inventory',  group: :nav },
      { label: 'Movimenti', path: inventories_movements_path,                icon: 'swap_vert',      can: 'manage_itemins',    group: :nav },
      { label: 'Seleziona', path: inventories_seleziona_path,                icon: 'checklist',      can: 'manage_inventory',  group: :actions },
      { label: 'Carico',    path: app_in_warehouse_path,                     icon: 'download',       can: 'manage_inventory',  group: :actions },
      { label: 'Scarico',   path: app_out_warehouse_path,                    icon: 'upload',         can: 'manage_inventory',  group: :actions },
      { label: 'Variaz.',   path: app_move_products_path,                    icon: 'swap_horiz',     can: 'manage_inventory',  group: :actions },
      { label: 'QR Select', path: inventories_qr_select_path,                icon: 'qr_code',        can: 'manage_inventory',  group: :actions, type: :action },
      { label: 'Import',    path: inventories_import_path,                   icon: 'file_upload',    can: 'manage_inventory',  group: :actions, type: :action },
      { label: 'Magazzini', path: warehouses_path,                           icon: 'warehouse',      can: 'manage_warehouses', group: :admin },
      { label: 'Ubicazioni',path: locations_path,                            icon: 'location_on',    can: 'manage_locations',  group: :admin },
      { label: 'Unisci',    path: merge_warehouses_path,                     icon: 'merge',          can: 'manage_warehouses', group: :admin, type: :action },
    ]
    items = items.select { |i| i[:can].nil? || current_user.can?(i[:can]) }
    return items if skip_config
    ToolbarConfig.filter_items(:inventories, items)
  end
end
