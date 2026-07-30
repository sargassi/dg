class AddManageArchiveAbility < ActiveRecord::Migration[7.2]
  def change
    Ability.find_or_create_by!(name: "manage_archive") do |a|
      a.description = "Gestione archivio"
      a.category = "archive"
    end
  end
end
