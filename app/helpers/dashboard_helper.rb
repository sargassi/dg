module DashboardHelper
  def portal_sections
    {
      articoli: {
        label: 'Articoli',
        icon: 'shelf_position',
        items: from_toolbar(:mainware_section_toolbar)
      },
      magazzino: {
        label: 'Magazzino',
        icon: 'inventory_2',
        items: from_toolbar(:inventories_section_toolbar)
      },
      produzione: {
        label: 'Produzione',
        icon: 'checklist_rtl',
        items: from_toolbar(:production_section_toolbar)
      },
      utilita: {
        label: 'Utilità',
        icon: 'description',
        items: from_toolbar(:utilities_section_toolbar)
      },
      archivio: {
        label: 'Archivio',
        icon: 'archive',
        items: from_toolbar(:archive_section_toolbar)
      },
      anagrafiche: {
        label: 'Anagrafiche',
        icon: 'contact_page',
        items: from_toolbar(:directory_section_toolbar)
      }
    }.transform_values do |section|
      dashboard = section[:items].find { |i| i[:label] == 'Dashboard' }
      section.merge(
        dashboard: dashboard&.fetch(:path),
        items: section[:items].reject { |i| i[:label] == 'Dashboard' }
      )
    end
  end

  def portal_config
    [
      { label: 'Utenti', path: admin_users_path, icon: 'admin_panel_settings' },
      { label: 'Operazioni', path: operationtypes_path, icon: 'swap_vert' },
      { label: 'Unità', path: uoms_path, icon: 'straighten' },
      { label: 'Taglie', path: taglia_path, icon: 'straighten' },
      { label: 'Stazioni', path: stations_path, icon: 'fact_check' },
      { label: 'Aree', path: areas_path, icon: 'category' },
      { label: 'Racks', path: rails_path, icon: 'shelves' }
    ]
  end

  def portal_card_class
    'bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 shadow-sm px-6 py-5'
  end

  private

  def from_toolbar(method)
    send(method, skip_config: true).map do |i|
      label = i[:label] == 'Qr Select' ? 'Stampa QR' : i[:label]
      { label: label, path: i[:path] }
    end
  end
end