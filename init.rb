require_relative 'app/services/redmine_upgrade_advisor/version_requirement'
require_relative 'app/services/redmine_upgrade_advisor/compatibility_scanner'
require_relative 'app/services/redmine_upgrade_advisor/latest_version_checker'
require_relative 'app/services/redmine_upgrade_advisor/analyzer'

Redmine::Plugin.register :redmine_upgrade_advisor do
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

