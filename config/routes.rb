Rails.application.routes.draw do
  namespace :api, defaults: { format: :json } do
    namespace :v1, defaults: { format: :json } do
      root to: 'pages#index'
      post '/product_create', to: 'hooks#shopify_product_create_hook'
      post '/product_update', to: 'hooks#shopify_product_update_hook'
    end
  end
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
