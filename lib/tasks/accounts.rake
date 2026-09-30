namespace :accounts do
  desc "Unlock all accounts"
  task unlock_all: :environment do
    locked_accounts = Account.where(is_lock: true)
    count = locked_accounts.count

    locked_accounts.update_all(is_lock: false, updated_at: Time.current) if count.positive?

    puts "Unlocked #{count} account(s)."
  end
end
