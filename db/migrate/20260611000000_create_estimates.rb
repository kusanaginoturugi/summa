class CreateEstimates < ActiveRecord::Migration[8.1]
  def change
    create_table :estimates do |t|
      t.string :estimate_number, null: false
      t.date :issued_on, null: false
      t.date :valid_until, null: false
      t.string :issuer, null: false
      t.string :recipient, null: false
      t.decimal :tax_rate, precision: 5, scale: 2, default: 0, null: false
      t.text :note

      t.timestamps
    end
    add_index :estimates, :estimate_number, unique: true

    create_table :estimate_items do |t|
      t.references :estimate, null: false, foreign_key: true
      t.string :description, null: false
      t.integer :quantity, default: 1, null: false
      t.decimal :unit_price, precision: 15, scale: 2, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end
  end
end
