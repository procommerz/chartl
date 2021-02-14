Chartl::Engine.routes.draw do
  namespace :chartl do
    resources :charts, only: [:show, :update] do
      member do
        get :refresh
        get :refreshing
      end
    end
  end
end
