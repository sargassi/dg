class ToolbarConfig < ApplicationRecord
  validates :section, presence: true
  validates :item_label, presence: true, uniqueness: { scope: :section }

  scope :custom, -> { where.not(path: [nil, ""]) }

  SECTIONS = {
    mainware:    { label: "Articoli",    controller: :mainware_section_toolbar },
    inventories: { label: "Magazzino",   controller: :inventories_section_toolbar },
    production:  { label: "Produzione",  controller: :production_section_toolbar },
    utilities:   { label: "Utilità",     controller: :utilities_section_toolbar },
    directory:   { label: "Anagrafiche", controller: :directory_section_toolbar },
  }.freeze

  def self.visible?(section, label)
    where(section: section, item_label: label).where(visible: false).none?
  end

  def self.filter_items(section, items)
    filtered = items.select { |item| visible?(section, item[:label]) }
    custom = where(section: section).custom.where(visible: true).order(:position).map do |c|
      { label: c.item_label, path: c.path, icon: c.icon.presence || "link", group: :custom, type: :nav }
    end
    filtered + custom
  end
end
