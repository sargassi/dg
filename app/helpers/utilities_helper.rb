module UtilitiesHelper
  def utilities_section_toolbar(skip_config: false)
    items = [
      { label: 'Dashboard', path: utilities_dashboard_path,         icon: 'dashboard',    can: 'manage_utilities_labels', group: :nav },
      { label: 'Proforma',  path: utilities_etichette_path,         icon: 'label',        can: 'print_labels_proforma',   group: :nav },
      { label: 'Generiche', path: utilities_etichette_gen_path,     icon: 'description',  can: 'print_labels_gen',        group: :nav },
      { label: 'Lab',       path: utilities_etichette_lab_path,     icon: 'science',      can: 'print_labels_lab',        group: :nav },
      { label: 'Campione',  path: utilities_etichette_camp_path,    icon: 'agriculture',  can: 'print_labels_camp',       group: :nav },
      { label: 'Taglio',    path: utilities_etichette_check_path,   icon: 'content_cut',  can: 'print_labels_check',      group: :nav },
    ]
    items = items.select { |i| i[:can].nil? || current_user.can?(i[:can]) }
    return items if skip_config
    ToolbarConfig.filter_items(:utilities, items)
  end
end
