class AddVarToProws < ActiveRecord::Migration[7.0]
  def change
    add_column :prows, :lavaggio, :string
    add_column :prows, :dettagli, :string
    add_column :prows, :ngemelli, :string
    add_column :prows, :totngemelli, :string
    add_column :prows, :colgemelli, :string
    add_column :prows, :fornitore, :string
    add_column :prows, :tempolav, :string
  end
end
