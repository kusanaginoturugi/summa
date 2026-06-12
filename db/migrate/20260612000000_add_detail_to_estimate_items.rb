class AddDetailToEstimateItems < ActiveRecord::Migration[8.1]
  def change
    add_column :estimate_items, :detail, :text
  end
end
