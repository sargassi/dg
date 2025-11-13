class AddlabToProw < ActiveRecord::Migration[7.0]
  def change
    add_column :prows, :colfilcuc, :string
    add_column :prows, :lab, :string
  end
end
