Rails.application.routes.draw do
  get 'plugin_check',
      :to => 'redmine_plugin_check#index',
      :as => 'plugin_check'

  get 'plugin_check/ai_markdown',
      :to => 'redmine_plugin_check#ai_markdown',
      :as => 'plugin_check_ai_markdown'

  post 'plugin_check/ai_analysis',
       :to => 'redmine_plugin_check#ai_analysis',
       :as => 'plugin_check_ai_analysis'
end
