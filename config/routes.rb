Rails.application.routes.draw do
  get 'app/dashboard'
  get 'app/check_qr'
  get 'app/sez'
  get 'etilabs/import'
  get "etilabs/etichette"
  resources :etilabs
  get 'stages/dashboard'
  get 'stages/sections'
  get 'production/research'
  get 'production/research_qr'
  get 'production/checkpoint'
  get 'production/checkpoint_single'
  resources :tempesta
  resources :prows
  resources :proformas
  resources :stations
  devise_for :users
  resources :rails
  resources :taglia
  resources :areas
  get 'dashboard/home'
  get 'utilities/etichette'
  get 'utilities/etichette_lab'
  post 'utilities/etilabimp'
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
  root to: "dashboard#home"
end
