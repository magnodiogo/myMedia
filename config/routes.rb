Rails.application.routes.draw do
  devise_for :users
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"

  resources :media_types
  resources :credit_people, only: [:show, :edit, :update] do
    member do
      post :load_metadata
      post :update_wiki
      post :update_photo
    end
  end
  resources :albums, only: [:show, :edit, :update] do
    resources :album_releases, except: [:index, :show] do
      member do
        post :try_load_cover
        post :add_to_collection
      end
    end

    member do
      post :load_metadata
      patch :update_allmusic_url
      post :try_load_cover
    end

    resources :tracks, only: [], controller: "album_tracks" do
      member do
        get :show_lyrics
      end
    end
  end
  resources :artists do
    member do
      post :update_wiki
      post :update_photo
      post :load_discography
    end
  end
  resources :user_media, only: [:create, :update]
  resources :notifications, only: [:index, :show, :destroy] do
    collection do
      post :read_all
    end
  end
  patch "preferences", to: "preferences#update"

  namespace :admin do
    resource :settings, only: [:show, :update]
    resources :notifications, only: [:index, :new, :create, :destroy]
  end

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      post "auth/login", to: "auth#login"
      get "auth/me", to: "auth#me"
      resources :user_media, only: [:index, :show]
    end
  end

  resources :plans, only: [:index] do
    collection do
      post :upgrade
      post :downgrade
    end
  end
  get "media/barcode_lookup", to: "media#barcode_lookup", as: :barcode_lookup_media
  get "media/global_search", to: "media#global_search", as: :global_search_media
  post "media/:id/add_to_collection", to: "media#add_to_collection", as: :add_to_collection_media
  post "media/import_and_add", to: "media#import_and_add", as: :import_and_add_media
  resources :media do
    member do
      post :refresh_metadata
    end
    resources :tracks, only: [:create, :edit, :update, :destroy] do
      member do
        get :show_lyrics
        get :edit_lyrics
        patch :update_lyrics
      end
    end
  end


  post "sessions/switch_user", to: "sessions#switch_user", as: :switch_user_sessions
end
