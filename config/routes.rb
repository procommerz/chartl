Chartl::Engine.routes.draw do
  namespace :chartl do
    resources :charts, only: [:show, :update] do
      member do
        get :refresh
      end
    end
  end
end