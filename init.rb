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
  require_dependency File.join(plugin_path, 'app/services/redmine_plugin_check/target_version_catalog')
  require_dependency File.join(plugin_path, 'app/services/redmine_plugin_check/ai_markdown_report')
  require_dependency File.join(plugin_path, 'app/services/redmine_plugin_check/markdown_formatter')
  require_dependency File.join(plugin_path, 'app/services/redmine_plugin_check/ai_settings')
  require_dependency File.join(plugin_path, 'app/services/redmine_plugin_check/ai_client')
  require_dependency File.join(plugin_path, 'app/services/redmine_plugin_check/analyzer')
  require_dependency File.join(plugin_path, 'app/helpers/redmine_plugin_check_helper')
  require_dependency File.join(plugin_path, 'app/controllers/redmine_plugin_check_controller')
end

require_dependency File.join(plugin_path, 'app/services/redmine_plugin_check/ai_settings')

module RedminePluginCheck
  module MenuIcon
    module_function

    def admin_menu_options
      options = {
        :caption => :label_redmine_plugin_check,
        :html => { :class => admin_icon_class }
      }
      options[:icon] = admin_sprite_icon if admin_sprite_icon
      options
    end

    def admin_sprite_icon
      redmine_version_at_least?('6.0.0') ? 'plugins' : nil
    end

    def admin_icon_class
      redmine_version_at_least?('6.0.0') ? nil : 'icon icon-reload'
    end

    def redmine_version_at_least?(version)
      current = defined?(Redmine::VERSION) ? Redmine::VERSION.to_s : '0'
      current = current[/\d+(?:\.\d+)*/] || '0'
      Gem::Version.new(current) >= Gem::Version.new(version)
    rescue StandardError
      false
    end
  end
end
Redmine::Plugin.register :redmine_plugin_check do
  name 'Plugin Compatibility Check'
  author 'kbymhrs'
  description 'Diagnoses installed Redmine plugins before a Redmine version upgrade.'
  version '1.0.0'
  url 'https://github.com/kbymhrs/redmine_plugin_check'
  author_url 'https://github.com/kbymhrs'

  requires_redmine :version_or_higher => '3.0.0'

  settings :default => RedminePluginCheck::AiSettings::DEFAULTS,
           :partial => 'settings/redmine_plugin_check'

  menu :admin_menu,
       :plugin_check,
       { :controller => 'redmine_plugin_check', :action => 'index' },
       RedminePluginCheck::MenuIcon.admin_menu_options
end

