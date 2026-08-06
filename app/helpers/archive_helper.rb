module ArchiveHelper
  def archive_section_toolbar(skip_config: false)
    items = [
      { label: 'Dashboard',   path: archive_dashboard_path,        icon: 'dashboard',   can: 'manage_archive', group: :nav },
      { label: 'Articoli',    path: archive_items_path,            icon: 'archive',     can: 'manage_archive', group: :nav },
      { label: 'Categorie',   path: archive_categories_path,       icon: 'folder',      can: 'manage_archive', group: :nav },
      { label: 'Ubicazioni',  path: archive_locations_path,        icon: 'shelves',     can: 'manage_archive', group: :nav },
      { label: 'Import',      path: import_archive_items_path,     icon: 'file_upload', can: 'manage_archive', group: :actions, type: :action },
    ]
    items = items.select { |i| i[:can].nil? || current_user.can?(i[:can]) }
    return items if skip_config
    ToolbarConfig.filter_items(:archive, items)
  end
end
