plugin_path = File.dirname(__FILE__)

I18n.load_path += Dir[File.join(plugin_path, 'config', 'locales', '*.yml')]

Rails.configuration.autoload_paths += [
  File.join(plugin_path, 'app', 'controllers'),
  File.join(plugin_path, 'app', 'models'),
  File.join(plugin_path, 'app', 'helpers'),
  File.join(plugin_path, 'app', 'services')
]

Rails.configuration.to_prepare do
  require_dependency File.join(plugin_path, 'app/services/redmine_upgrade_advisor/version_requirement')
  require_dependency File.join(plugin_path, 'app/services/redmine_upgrade_advisor/compatibility_scanner')
  require_dependency File.join(plugin_path, 'app/services/redmine_upgrade_advisor/latest_version_checker')
  require_dependency File.join(plugin_path, 'app/services/redmine_upgrade_advisor/analyzer')
  require_dependency File.join(plugin_path, 'app/helpers/redmine_upgrade_advisor_helper')
  require_dependency File.join(plugin_path, 'app/controllers/redmine_upgrade_advisor_controller')
end

Redmine::Plugin.register :redmine_plugin_check do
  name 'Plugin Compatibility Check'
  author 'kbymhrs'
  description 'Diagnoses installed Redmine plugins before a Redmine version upgrade.'
  version '0.1.0'
  url 'https://github.com/kbymhrs/redmine_plugin_check'
  author_url 'https://github.com/kbymhrs'

  requires_redmine :version_or_higher => '3.3.0'

  menu :admin_menu,
       :plugin_check,
       { :controller => 'redmine_upgrade_advisor', :action => 'index' },
       :caption => :label_redmine_plugin_check,
       :html => { :class => 'icon icon-reload' }
end
