Rails.application.routes.draw do
  get 'etilabs/import'
  get "etilabs/etichette"
  resources :etilabs
  get 'stages/dashboard'
  get 'stages/sections'
  get 'production/research'
  get 'production/research_qr'
  get 'production/checkpoint'
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
  root to: "dashboard#home"
end
