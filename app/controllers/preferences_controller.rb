class PreferencesController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  def update
    pref_params = {}
    [:theme, :sidebar_collapsed, :view_preference, :media_card_size].each do |key|
      pref_params[key] = params[key] if params.has_key?(key)
    end

    if current_user
      current_user.update(pref_params)
    end

    pref_params.each do |key, value|
      cookies[key] = {
        value: value,
        expires: 1.year.from_now,
        path: '/'
      }
    end

    head :ok
  end
end
