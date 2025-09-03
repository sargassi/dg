class ChangeDataToTempestas < ActiveRecord::Migration[7.0]
  def change
    change_column :tempesta, :f1date, :date
    change_column :tempesta, :f2date, :date
    change_column :tempesta, :f3date, :date
    change_column :tempesta, :f4date, :date
    change_column :tempesta, :f5date, :date
  end
end
