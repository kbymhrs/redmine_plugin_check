require File.expand_path('../../test_helper', File.dirname(__FILE__))

require 'fileutils'
require 'tmpdir'
require_relative '../../../app/services/redmine_plugin_check/compatibility_scanner' unless defined?(RedminePluginCheck::CompatibilityScanner)
require_relative '../../../app/services/redmine_plugin_check/latest_version_checker' unless defined?(RedminePluginCheck::LatestVersionChecker)
require_relative '../../../app/services/redmine_plugin_check/version_requirement' unless defined?(RedminePluginCheck::VersionRequirement)
require_relative '../../../app/services/redmine_plugin_check/analyzer' unless defined?(RedminePluginCheck::Analyzer)

class RedminePluginCheckAnalyzerTest < ActiveSupport::TestCase
  FakePlugin = Struct.new(:id, :name, :version, :author, :directory, :requires_redmine)

  test 'marks plugin risky when target version does not satisfy requires_redmine' do
    Dir.mktmpdir do |dir|
      plugin_dir = File.join(dir, 'legacy_plugin')
      Dir.mkdir(plugin_dir)
      File.write(File.join(plugin_dir, 'init.rb'), "Redmine::Plugin.register :legacy_plugin do\nend\n")
      plugin = FakePlugin.new(:legacy_plugin, 'Legacy Plugin', '1.0.0', 'ACME', plugin_dir, { :version => '5.0.0' })

      report = RedminePluginCheck::Analyzer.new(:target_version => '6.0.0', :plugins => [plugin]).call

      assert_equal 'Risky', report.plugins.first.status
    end
  end

  test 'marks plugin warning when it has migrations' do
    Dir.mktmpdir do |dir|
      plugin_dir = File.join(dir, 'migrating_plugin')
      FileUtils.mkdir_p(File.join(plugin_dir, 'db', 'migrate'))
      File.write(File.join(plugin_dir, 'init.rb'), "Redmine::Plugin.register :migrating_plugin do\nend\n")
      plugin = FakePlugin.new(:migrating_plugin, 'Migrating Plugin', '1.0.0', 'ACME', plugin_dir, { :version_or_higher => '5.0.0' })

      report = RedminePluginCheck::Analyzer.new(:target_version => '6.0.0', :plugins => [plugin]).call

      assert_equal 'Warning', report.plugins.first.status
      assert report.plugins.first.has_migrations
    end
  end

  test 'keeps lower-bound-only requires_redmine informational on major target jump' do
    Dir.mktmpdir do |dir|
      plugin_dir = File.join(dir, 'lower_bound_plugin')
      Dir.mkdir(plugin_dir)
      File.write(File.join(plugin_dir, 'init.rb'), "Redmine::Plugin.register :lower_bound_plugin do\nend\n")
      plugin = FakePlugin.new(:lower_bound_plugin, 'Lower Bound Plugin', '1.0.0', 'ACME', plugin_dir, { :version_or_higher => '3.3.0' })

      report = RedminePluginCheck::Analyzer.new(:target_version => '6.0.0', :plugins => [plugin]).call
      plugin_report = report.plugins.first

      assert_equal 'OK', plugin_report.status
      assert plugin_report.requires_redmine_lower_bound_only
      assert plugin_report.target_major_jump
      assert plugin_report.last_modified_at
      assert_includes plugin_report.notes, :requires_redmine_lower_bound_only
    end
  end

  test 'marks risky legacy patterns as risky for modern target versions' do
    Dir.mktmpdir do |dir|
      plugin_dir = File.join(dir, 'legacy_api_plugin')
      FileUtils.mkdir_p(File.join(plugin_dir, 'lib'))
      File.write(File.join(plugin_dir, 'init.rb'), "Redmine::Plugin.register :legacy_api_plugin do\nend\n")
      File.write(File.join(plugin_dir, 'lib', 'patch.rb'), "base.class_eval do\n  alias_method_chain :foo, :bar\nend\n")
      plugin = FakePlugin.new(:legacy_api_plugin, 'Legacy API Plugin', '1.0.0', 'ACME', plugin_dir, { :version_or_higher => '3.3.0' })

      report = RedminePluginCheck::Analyzer.new(:target_version => '6.0.0', :plugins => [plugin]).call
      plugin_report = report.plugins.first

      assert_equal 'Risky', plugin_report.status
      assert_equal :alias_method_chain, plugin_report.compatibility_findings.first.key
      assert_includes plugin_report.notes, :legacy_breaking_patterns_detected
    end
  end
  test 'does not treat explanatory alias method chain text as a risky call' do
    Dir.mktmpdir do |dir|
      plugin_dir = File.join(dir, 'self_documenting_plugin')
      FileUtils.mkdir_p(File.join(plugin_dir, 'app', 'helpers'))
      File.write(File.join(plugin_dir, 'init.rb'), "Redmine::Plugin.register :self_documenting_plugin do\nend\n")
      File.write(File.join(plugin_dir, 'app', 'helpers', 'helper.rb'), "NOTES = [:alias_method_chain_breaking]\n")
      plugin = FakePlugin.new(:self_documenting_plugin, 'Self Documenting Plugin', '1.0.0', 'ACME', plugin_dir, { :version_or_higher => '3.3.0' })

      report = RedminePluginCheck::Analyzer.new(:target_version => '6.0.0', :plugins => [plugin]).call
      plugin_report = report.plugins.first

      assert_equal 'OK', plugin_report.status
      assert plugin_report.compatibility_findings.empty?
    end
  end
end
