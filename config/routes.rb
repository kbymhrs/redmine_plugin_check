Rails.application.routes.draw do
  get 'plugin_check',
      :to => 'redmine_upgrade_advisor#index',
      :as => 'plugin_check'
end
