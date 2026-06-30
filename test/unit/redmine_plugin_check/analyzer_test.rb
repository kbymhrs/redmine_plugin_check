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
      plugin_report = report.plugins.first

      assert_equal 'Risky', plugin_report.status
      assert_includes plugin_report.primary_reasons, :target_version_outside_requires_redmine
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
      assert_includes report.plugins.first.primary_reasons, :has_database_migrations
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
      assert_empty plugin_report.primary_reasons
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
      assert_equal 2, plugin_report.compatibility_findings.first.line
      assert_includes plugin_report.primary_reasons, :alias_method_chain_breaking
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

  test 'ignores legacy api names in ruby comments' do
    Dir.mktmpdir do |dir|
      plugin_dir = File.join(dir, 'commented_plugin')
      FileUtils.mkdir_p(File.join(plugin_dir, 'lib'))
      File.write(File.join(plugin_dir, 'init.rb'), "Redmine::Plugin.register :commented_plugin do\nend\n")
      File.write(File.join(plugin_dir, 'lib', 'patch.rb'), "# alias_method_chain :foo, :bar\n# before_filter :old\n")
      plugin = FakePlugin.new(:commented_plugin, 'Commented Plugin', '1.0.0', 'ACME', plugin_dir, { :version_or_higher => '3.3.0' })

      report = RedminePluginCheck::Analyzer.new(:target_version => '6.0.0', :plugins => [plugin]).call
      plugin_report = report.plugins.first

      assert_equal 'OK', plugin_report.status
      assert plugin_report.compatibility_findings.empty?
    end
  end

  test 'adds missing requires_redmine to primary reasons for unknown plugins' do
    Dir.mktmpdir do |dir|
      plugin_dir = File.join(dir, 'unknown_plugin')
      Dir.mkdir(plugin_dir)
      File.write(File.join(plugin_dir, 'init.rb'), "Redmine::Plugin.register :unknown_plugin do\nend\n")
      plugin = FakePlugin.new(:unknown_plugin, 'Unknown Plugin', '1.0.0', 'ACME', plugin_dir, nil)

      report = RedminePluginCheck::Analyzer.new(:target_version => '6.0.0', :plugins => [plugin]).call
      plugin_report = report.plugins.first

      assert_equal 'Unknown', plugin_report.status
      assert_includes plugin_report.primary_reasons, :requires_redmine_missing
    end
  end

  test 'keeps lower-bound-only plugin ok when target version is blank' do
    Dir.mktmpdir do |dir|
      plugin_dir = File.join(dir, 'blank_target_plugin')
      Dir.mkdir(plugin_dir)
      File.write(File.join(plugin_dir, 'init.rb'), "Redmine::Plugin.register :blank_target_plugin do\nend\n")
      plugin = FakePlugin.new(:blank_target_plugin, 'Blank Target Plugin', '1.0.0', 'ACME', plugin_dir, { :version_or_higher => '3.3.0' })

      report = RedminePluginCheck::Analyzer.new(:target_version => '', :plugins => [plugin]).call
      plugin_report = report.plugins.first

      assert_equal 'OK', plugin_report.status
      assert_nil plugin_report.requires_redmine_satisfied
      assert plugin_report.requires_redmine_lower_bound_only
      assert_empty plugin_report.primary_reasons
      assert_includes plugin_report.notes, :target_version_missing
    end
  end
end
