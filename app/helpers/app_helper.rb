module AppHelper
  def app_section_toolbar
    items = [
      { label: 'Home',        path: app_dashboard_path,            icon: 'home',                  can: 'manage_app_sectors', group: :nav },
      { label: 'Articoli',    path: app_dashboard_articoli_path,   icon: 'inventory_2',          can: 'manage_app_sectors', group: :nav },
      { label: 'Magazzino',   path: app_dashboard_magazzino_path,  icon: 'warehouse',            can: 'manage_app_sectors', group: :nav },
      { label: 'Produzione',  path: app_dashboard_produzione_path, icon: 'precision_manufacturing', can: 'manage_app_sectors', group: :nav },
      { label: 'Inserimento', path: app_inserimento_path,          icon: 'add_box',              can: 'manage_app_sectors', group: :actions, type: :action },
      { label: 'IN',          path: app_mobile_in_path,           icon: 'download',             can: 'manage_app_sectors', group: :actions, type: :action },
      { label: 'OUT',         path: app_mobile_out_path,          icon: 'upload',               can: 'manage_app_sectors', group: :actions, type: :action },
      { label: 'VAR',         path: app_mobile_var_path,          icon: 'swap_horiz',           can: 'manage_app_sectors', group: :actions, type: :action },
    ]
    items.select { |i| i[:can].nil? || current_user.can?(i[:can]) }
  end
end
