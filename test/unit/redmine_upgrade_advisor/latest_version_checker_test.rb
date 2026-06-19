require File.expand_path('../../test_helper', File.dirname(__FILE__))

require 'fileutils'
require 'tmpdir'
require_relative '../../../app/services/redmine_upgrade_advisor/latest_version_checker'

class RedmineUpgradeAdvisorLatestVersionCheckerTest < ActiveSupport::TestCase
  FakePlugin = Struct.new(:url)

  test 'extracts github repository from common urls' do
    assert_equal ['redmine', 'redmine'], RedmineUpgradeAdvisor::LatestVersionChecker.github_repository_from_url('https://github.com/redmine/redmine')
    assert_equal ['redmine', 'redmine'], RedmineUpgradeAdvisor::LatestVersionChecker.github_repository_from_url('https://github.com/redmine/redmine.git')
    assert_equal ['redmine', 'redmine'], RedmineUpgradeAdvisor::LatestVersionChecker.github_repository_from_url('git@github.com:redmine/redmine.git')
    assert_equal ['redmine', 'redmine'], RedmineUpgradeAdvisor::LatestVersionChecker.github_repository_from_url('ssh://git@github.com/redmine/redmine.git')
  end

  test 'returns source missing when no github source is available' do
    Dir.mktmpdir do |dir|
      plugin = FakePlugin.new('https://example.com/plugin')
      result = RedmineUpgradeAdvisor::LatestVersionChecker.new(plugin, dir).call

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
      checker = RedmineUpgradeAdvisor::LatestVersionChecker.new(plugin, dir)

      assert_equal ['redmine', 'redmine'], checker.send(:github_repository)
    end
  end
end
