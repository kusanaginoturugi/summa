Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :vouchers, only: %i[index new create edit update destroy]
  get "vouchers/quick" => "vouchers#quick", as: :quick_vouchers
  post "vouchers/quick" => "vouchers#create_quick"
  get "vouchers/register" => "vouchers#register", as: :register_vouchers
  post "vouchers/register" => "vouchers#create_register"
  get "vouchers/register_monthly" => "vouchers#register_monthly", as: :register_monthly_vouchers
  patch "vouchers/register/lines/:id" => "vouchers#update_register_line", as: :update_register_voucher_line
  resources :bank_imports, only: %i[new create]
  resources :accounts, only: %i[index new create edit update destroy] do
    get :summary, on: :collection
    get :entries, on: :member
  end
  resources :voucher_lines, only: [] do
    patch :update_counterpart, on: :member
  end

  # Defines the root path route ("/")
  root "vouchers#new"
end
