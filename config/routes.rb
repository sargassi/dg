Rails.application.routes.draw do
  resources :inventories
  resources :items
  resources :itemouts
  scope '/mainware' do
    resources :warehouses
    resources :locations
  end
  resources :itemins
  resources :operationtypes
  resources :uoms
  resources :operators
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
  devise_for :users
  resources :rails
  resources :taglia
  resources :areas
  get 'dashboard/home'
  get 'utilities/etichette'
  get 'utilities/etichette_camp'
  get 'utilities/etichette_lab'
  get 'utilities/etichette_gen'
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
