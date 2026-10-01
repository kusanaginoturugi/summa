class AddShortNameToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :short_name, :string
  end
end
