module ProductionHelper
  def production_section_toolbar(skip_config: false)
    items = [
      { label: 'Dashboard',  path: production_dashboard_path,    icon: 'dashboard',       can: 'view_production',    group: :nav },
      { label: 'Lanci',      path: production_proformas_path,    icon: 'checklist_rtl',   can: 'manage_proformas',   group: :nav },
      { label: 'Ricerca',    path: production_research_path,     icon: 'search_insights', can: 'view_production',    group: :nav },
      { label: 'Ricerca QR', path: production_research_qr_path,  icon: 'qr_code_scanner', can: 'view_production',    group: :nav },
      { label: 'Checkpoint', path: production_checkpoint_single_path, icon: 'fact_check', can: 'view_production',  group: :actions, type: :action },
    ]
    items = items.select { |i| i[:can].nil? || current_user.can?(i[:can]) }
    return items if skip_config
    ToolbarConfig.filter_items(:production, items)
  end
end
