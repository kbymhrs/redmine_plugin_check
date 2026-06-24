require File.expand_path('../../test_helper', File.dirname(__FILE__))

require 'fileutils'
require 'tmpdir'
require_relative '../../../app/services/redmine_plugin_check/latest_version_checker' unless defined?(RedminePluginCheck::LatestVersionChecker)

class RedminePluginCheckLatestVersionCheckerTest < ActiveSupport::TestCase
  FakePlugin = Struct.new(:url)

  test 'extracts github repository from common urls' do
    assert_equal ['redmine', 'redmine'], RedminePluginCheck::LatestVersionChecker.github_repository_from_url('https://github.com/redmine/redmine')
    assert_equal ['redmine', 'redmine'], RedminePluginCheck::LatestVersionChecker.github_repository_from_url('https://github.com/redmine/redmine.git')
    assert_equal ['redmine', 'redmine'], RedminePluginCheck::LatestVersionChecker.github_repository_from_url('git@github.com:redmine/redmine.git')
    assert_equal ['redmine', 'redmine'], RedminePluginCheck::LatestVersionChecker.github_repository_from_url('ssh://git@github.com/redmine/redmine.git')
  end

  test 'returns source missing when no github source is available' do
    Dir.mktmpdir do |dir|
      plugin = FakePlugin.new('https://example.com/plugin')
      result = RedminePluginCheck::LatestVersionChecker.new(plugin, dir).call

      assert_nil result.version
      assert_nil result.source
      assert_equal :source_missing, result.error
    end
  end

  test 'uses git origin as a source candidate' do
    Dir.mktmpdir do |dir|
      git_dir = File.join(dir, '.git')
      FileUtils.mkdir_p(git_dir)
      File.write(File.join(git_dir, 'config'), "[remote \"origin\"]\n  url = git@github.com:redmine/redmine.git\n")

      plugin = FakePlugin.new(nil)
      checker = RedminePluginCheck::LatestVersionChecker.new(plugin, dir)

      assert_equal ['redmine', 'redmine'], checker.send(:github_repository)
    end
  end
  test 'returns request failed when github api cannot be reached' do
    Dir.mktmpdir do |dir|
      plugin = FakePlugin.new('https://github.com/redmine/redmine')
      checker = RedminePluginCheck::LatestVersionChecker.new(plugin, dir)
      checker.define_singleton_method(:get_json) do |_url|
        @request_failed = true
        nil
      end
      checker.define_singleton_method(:get_text) do |_url|
        @request_failed = true
        nil
      end

      result = checker.call

      assert_nil result.version
      assert_equal 'https://github.com/redmine/redmine', result.source
      assert_equal :request_failed, result.error
    end
  end

  test 'falls back to github tags page html' do
    Dir.mktmpdir do |dir|
      plugin = FakePlugin.new('https://github.com/redmine/redmine')
      checker = RedminePluginCheck::LatestVersionChecker.new(plugin, dir)
      checker.define_singleton_method(:get_json) { |_url| nil }
      checker.define_singleton_method(:get_text) do |_url|
        '<a href="/redmine/redmine/releases/tag/v6.1.2">v6.1.2</a>'
      end

      result = checker.call

      assert_equal 'v6.1.2', result.version
      assert_equal 'https://github.com/redmine/redmine', result.source
      assert_nil result.error
    end
  end
end
