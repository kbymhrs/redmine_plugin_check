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

  post 'plugin_check/ai_analysis_download',
       :to => 'redmine_plugin_check#ai_analysis_download',
       :as => 'plugin_check_ai_analysis_download'

  get 'plugin_check/ai_models',
      :to => 'redmine_plugin_check#ai_models',
      :as => 'plugin_check_ai_models'

  get 'plugin_check/ai_test_connection',
      :to => 'redmine_plugin_check#ai_test_connection',
      :as => 'plugin_check_ai_test_connection'
end

