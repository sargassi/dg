Rails.application.routes.draw do
  devise_for :users
  resources :rails
  resources :taglia
  resources :areas
  get 'dashboard/home'
  get 'utilities/etichette'  
  get 'products_imports/new'
  get 'products_imports/create'
  get "products/etichette"
  resources :products
  resources :rassegnas
  resources :products_imports, only: [:new, :create]
  root to: "dashboard#home"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
