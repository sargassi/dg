Rails.application.routes.draw do
  resources :collections do
    collection do
      post :reorder
    end
  end
  get 'etichecks/etichette'
  resources :etichecks
  get 'inventories/dashboard'
  get 'inventories/movements'
  get 'inventories/movements/:type/:id/label', to: 'inventories#movement_label', as: :inventories_movement_label, defaults: { format: :pdf }
  get 'inventories/movements/:type/:id/modal', to: 'inventories#movement_modal', as: :inventories_movement_modal
  get 'inventories/seleziona'
  post 'inventories/seleziona/prepare_carico', to: 'inventories#prepare_carico', as: :inventories_prepare_carico
  get 'inventories/import'
  post   'inventories/import/parse',      to: 'inventories#import_parse'
  put    'inventories/import/update_row', to: 'inventories#import_update_row'
  delete 'inventories/import/delete_row', to: 'inventories#import_delete_row'
  post   'inventories/import/confirm',    to: 'inventories#import_confirm'
  delete 'inventories/import/cancel',     to: 'inventories#import_cancel'
  get    'inventories/import/summary',    to: 'inventories#import_summary'
  scope '/inventories' do
    resources :warehouses do
      collection do
        get 'qrcodes', defaults: { format: :pdf }
        get 'lookup_by_qr'
      end
    end
    resources :locations
    resources :itemins do
      collection do
        get  :preview
        post :confirm
      end
      resources :itemins_details, only: [:index, :create, :update, :destroy]
    end
    resources :itemouts do
      collection do
        get  :preview
        post :confirm
      end
    end
  end
  get '/itemins(/*path)' => redirect('/inventories/itemins/%{path}')
  get '/itemouts(/*path)' => redirect('/inventories/itemouts/%{path}')
  resources :inventories do
    collection do
      get 'autocomplete'
      get 'lookup_by_qr'
    end
  end
  resources :items do
    collection do
      get 'autocomplete'
      get 'distinct_values'
      get 'create_confirmation'
    end
    member do
      delete 'delete_picture'
      get 'gallery'
      get 'price_history'
    end
  end
  resources :operationtypes
  resources :uoms

  get 'mainware/home'
  get 'mainware/index'
  get 'mainware/search'
  get 'mainware/import'
  post   'mainware/import/parse',      to: 'mainware#import_parse'
  put    'mainware/import/update_row', to: 'mainware#import_update_row'
  delete 'mainware/import/delete_row', to: 'mainware#import_delete_row'
  post   'mainware/import/confirm',    to: 'mainware#import_confirm'
  delete 'mainware/import/cancel',     to: 'mainware#import_cancel'
  delete 'mainware/import/rollback',   to: 'mainware#import_rollback'
  get    'mainware/import/processing', to: 'mainware#import_processing'
  get    'mainware/import/progress',   to: 'mainware#import_progress_json'
  get    'mainware/import/summary',    to: 'mainware#import_summary'
  get 'mainware/dashboard'
  get 'mainware/prices_compare', to: 'mainware#prices_compare'
  get 'mainware/searchqr'
  mount API::Base, at: "/"

  get 'eticamps/etichette'
  resources :eticamps
  namespace :directory do
    resources :events do
      collection do
        get :search
      end
      member do
        patch :toggle_enabled
      end
    end
  end
  resources :eventypes
  get 'etigens/etichette'
  resources :etigens
  resources :fabriclus
  get 'app/dashboard'
  get 'app/dashboard_articoli', to: 'app#dashboard_articoli', as: :app_dashboard_articoli
  get 'app/dashboard_magazzino', to: 'app#dashboard_magazzino', as: :app_dashboard_magazzino
  get 'app/dashboard_produzione', to: 'app#dashboard_produzione', as: :app_dashboard_produzione
  match 'app/in_warehouse', to: 'app#in_warehouse', via: [:get, :post], as: :app_in_warehouse
  get 'app/in_warehouse_confirmation', to: 'app#in_warehouse_confirmation', as: :app_in_warehouse_confirmation
  get 'app/itemins_list', to: 'app#itemins_list', as: :app_itemins_list
  get 'app/itemouts_list', to: 'app#itemouts_list', as: :app_itemouts_list
  get 'app/itemmovements_list', to: 'app#itemmovements_list', as: :app_itemmovements_list
  match 'app/out_warehouse', to: 'app#out_warehouse', via: [:get, :post], as: :app_out_warehouse
  get 'app/out_warehouse_confirmation', to: 'app#out_warehouse_confirmation', as: :app_out_warehouse_confirmation
  match 'app/move_products', to: 'app#move_products', via: [:get, :post], as: :app_move_products
  get 'app/move_products_confirmation', to: 'app#move_products_confirmation', as: :app_move_products_confirmation
  match 'app/inserimento', to: 'app#inserimento', via: [:get, :post], as: :app_inserimento
  get 'app/confirm_ins', to: 'app#confirm_ins', as: :app_confirm_ins
  get 'app/check_single_qr'
  get 'app/sez'
  get 'etilabs/import'
  get "etilabs/etichette"
  resources :etilabs
  get 'stages/dashboard'
  get 'stages/sections'
  get 'production/dashboard'
  get 'production/research'
  get 'production/research_qr'
  get 'production/checkpoint'
  get 'production/checkpoint_single'
  get 'tempesta/set_f'
  resources :tempesta
  resources :prows
  namespace :production do
    resources :proformas
  end
  resources :stations
  namespace :admin do
    resources :users, only: [:index, :new, :create, :edit, :update, :destroy] do
      member do
        get :abilities
      end
    end
  end

  devise_for :users
  resources :rails
  resources :taglia
  resources :areas
  get 'directory/dashboard' => 'directory#dashboard', as: :directory_dashboard
  get 'directory' => 'directory#index'
  get 'directory/:id' => 'directory#show', as: :directory_user
  get 'directory/:id/edit' => 'directory#edit', as: :edit_directory_user
  patch 'directory/:id' => 'directory#update'
  resource :profile, only: [:edit, :update], controller: 'profiles'
  get 'dashboard/home'
  get 'utilities/dashboard'
  get 'utilities/etichette'
  get 'utilities/etichette_check'
  get 'utilities/etichette_camp'
  get 'utilities/etichette_lab'
  get 'utilities/etichette_gen'
  post 'utilities/eticheckimp'
  post 'utilities/eticampimp'
  post 'utilities/etilabimp'
  post 'utilities/etilgenimp'
  get 'products_imports/new'
  get 'products_imports/create'
  get "products/etichette"
  resources :products
  resources :rassegnas
  resources :products_imports, only: [:new, :create]
  namespace :api do
    namespace :v1 do
      defaults format: :json do
        get "home/index", to: "home#index" # /api/v1/home/index
        get "home/list_qrs"
      end
    end
  end

  root to: "dashboard#index"
end
