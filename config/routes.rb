Rails.application.routes.draw do
  get 'plugin_check',
      :to => 'redmine_plugin_check#index',
      :as => 'plugin_check'
end
