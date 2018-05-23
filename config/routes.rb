Chartl::Engine.routes.draw do
  namespace :chartl do
    resources :charts, only: [:show, :update]
  end
end