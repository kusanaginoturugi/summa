class AddIsLockToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :is_lock, :boolean, default: false, null: false
  end
end
