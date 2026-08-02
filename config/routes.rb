Rails.application.routes.draw do
  root "pages#home"

  get "pages/aboutme"
  get "pages/contactme"

  get "projects/show"
  get "projects/mightylocksmith"
  get "projects/portfolio"
  get "projects/fafsa"

  # Returns 200 if the app booted without exceptions, otherwise 500.
  # Heroku's router does not use this, but uptime monitors can.
  get "up" => "rails/health#show", as: :rails_health_check

  # For details on the DSL available within this file, see
  # https://guides.rubyonrails.org/routing.html
end
