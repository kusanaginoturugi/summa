class AddIssuerToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :issuer, :text
  end
end
