Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"

  resources :media_types
  resources :artists
  get "media/barcode_lookup", to: "media#barcode_lookup", as: :barcode_lookup_media
  get "media/global_search", to: "media#global_search", as: :global_search_media
  post "media/:id/add_to_collection", to: "media#add_to_collection", as: :add_to_collection_media
  post "media/import_and_add", to: "media#import_and_add", as: :import_and_add_media
  resources :media do
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
