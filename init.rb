plugin_path = File.dirname(__FILE__)

I18n.load_path += Dir[File.join(plugin_path, 'config', 'locales', '*.yml')]

Rails.configuration.autoload_paths += [
  File.join(plugin_path, 'app', 'controllers'),
  File.join(plugin_path, 'app', 'models'),
  File.join(plugin_path, 'app', 'helpers'),
  File.join(plugin_path, 'app', 'services')
]

Rails.configuration.to_prepare do
  require_dependency File.join(plugin_path, 'app/services/redmine_plugin_check/version_requirement')
  require_dependency File.join(plugin_path, 'app/services/redmine_plugin_check/compatibility_scanner')
  require_dependency File.join(plugin_path, 'app/services/redmine_plugin_check/latest_version_checker')
  require_dependency File.join(plugin_path, 'app/services/redmine_plugin_check/ai_markdown_report')
  require_dependency File.join(plugin_path, 'app/services/redmine_plugin_check/ai_settings')
  require_dependency File.join(plugin_path, 'app/services/redmine_plugin_check/ai_client')
  require_dependency File.join(plugin_path, 'app/services/redmine_plugin_check/analyzer')
  require_dependency File.join(plugin_path, 'app/helpers/redmine_plugin_check_helper')
  require_dependency File.join(plugin_path, 'app/controllers/redmine_plugin_check_controller')
end

require_dependency File.join(plugin_path, 'app/services/redmine_plugin_check/ai_settings')

Redmine::Plugin.register :redmine_plugin_check do
  name 'Plugin Compatibility Check'
  author 'kbymhrs'
  description 'Diagnoses installed Redmine plugins before a Redmine version upgrade.'
  version '0.1.1'
  url 'https://github.com/kbymhrs/redmine_plugin_check'
  author_url 'https://github.com/kbymhrs'

  requires_redmine :version_or_higher => '3.3.0'

  settings :default => RedminePluginCheck::AiSettings::DEFAULTS,
           :partial => 'settings/redmine_plugin_check'

  menu :admin_menu,
       :plugin_check,
       { :controller => 'redmine_plugin_check', :action => 'index' },
       :caption => :label_redmine_plugin_check,
       :html => { :class => 'icon icon-reload' }
end
