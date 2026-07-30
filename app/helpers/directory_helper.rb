module DirectoryHelper
  def directory_section_toolbar(skip_config: false)
    items = [
      { label: 'Dashboard',  path: directory_dashboard_path,        icon: 'dashboard',      can: 'manage_directory',        group: :nav },
      { label: 'Anagrafiche',path: directory_path,                  icon: 'contact_page',   can: 'manage_directory',        group: :nav },
      { label: 'Calendario', path: directory_events_path,           icon: 'calendar_month', can: 'manage_events_calendar',  group: :nav },
      { label: 'Cerca Eventi',path: search_directory_events_path,   icon: 'search',         can: 'manage_events_calendar',  group: :nav },
    ]
    items = items.select { |i| i[:can].nil? || current_user.can?(i[:can]) }
    return items if skip_config
    ToolbarConfig.filter_items(:directory, items)
  end
end
