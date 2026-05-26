Rails.application.routes.draw do
  resources :collections
  get 'etichecks/etichette'
  resources :etichecks
  get 'inventories/dashboard'
  get 'inventories/import'
  post   'inventories/import/parse',      to: 'inventories#import_parse'
  put    'inventories/import/update_row', to: 'inventories#import_update_row'
  delete 'inventories/import/delete_row', to: 'inventories#import_delete_row'
  post   'inventories/import/confirm',    to: 'inventories#import_confirm'
  delete 'inventories/import/cancel',     to: 'inventories#import_cancel'
  get    'inventories/import/summary',    to: 'inventories#import_summary'
  scope '/inventories' do
    resources :warehouses
    resources :locations
    resources :itemins do
      resources :itemins_details, only: [:index, :create, :update, :destroy]
    end
    resources :itemouts
  end
  get '/itemins(/*path)' => redirect('/inventories/itemins/%{path}')
  get '/itemouts(/*path)' => redirect('/inventories/itemouts/%{path}')
  resources :inventories
  resources :items do
    collection do
      get 'autocomplete'
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
  get    'mainware/import/summary',    to: 'mainware#import_summary'
  get 'mainware/dashboard'
  get 'mainware/prices_compare', to: 'mainware#prices_compare'
  get 'mainware/searchqr'
  mount API::Base, at: "/"

  get 'eticamps/etichette'
  resources :eticamps
  resources :events
  resources :eventypes
  get 'etigens/etichette'
  resources :etigens
  resources :fabriclus
  get 'app/dashboard'
  get 'app/check_qr'
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
    resources :users, only: [:index, :new, :create, :edit, :update, :destroy]
  end

  devise_for :users
  resources :rails
  resources :taglia
  resources :areas
  get 'directory' => 'directory#index'
  get 'directory/:id' => 'directory#show', as: :directory_user
  get 'directory/:id/edit' => 'directory#edit', as: :edit_directory_user
  patch 'directory/:id' => 'directory#update'
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

  get 'basic-qr-code-reader', to: 'basic_qr_codes#index'
  get 'basic_qr_codes/qrcheck'

  root to: "dashboard#index"
end
