Rails.application.routes.draw do
  root  'pages#home'
  get   'pages/aboutme'
  get   'pages/contactme'
  get   'projects/show'
  get   'projects/mightylock'
  get   'projects/portfolio'
  
  
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
