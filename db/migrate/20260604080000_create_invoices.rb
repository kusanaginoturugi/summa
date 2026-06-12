class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.string :invoice_number, null: false
      t.string :client_name, null: false
      t.date :invoice_date, null: false
      t.date :due_date, null: false
      t.string :title, null: false
      t.text :items_json, null: false
      t.decimal :subtotal, precision: 15, scale: 2, default: "0.0", null: false
      t.decimal :tax, precision: 15, scale: 2, default: "0.0", null: false
      t.decimal :total, precision: 15, scale: 2, default: "0.0", null: false
      t.text :note
      t.references :voucher, foreign_key: true
      t.string :pdf_path
      t.datetime :issued_at

      t.timestamps
    end

    add_index :invoices, :invoice_number, unique: true
    add_index :invoices, :invoice_date
  end
end
