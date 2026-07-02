require File.expand_path('../../test_helper', File.dirname(__FILE__))

require_relative '../../../app/services/redmine_plugin_check/target_version_catalog' unless defined?(RedminePluginCheck::TargetVersionCatalog)

class RedminePluginCheckTargetVersionCatalogTest < ActiveSupport::TestCase
  test 'parses stable version tags only' do
    catalog = RedminePluginCheck::TargetVersionCatalog.new
    html = '<a href="6.1.2/">6.1.2/</a><a href="6.1.3/">6.1.3/</a><a href="6.2.0-RC1/">6.2.0-RC1/</a>'

    assert_equal ['6.1.2', '6.1.3'], catalog.parse_versions(html)
  end

  test 'returns versions greater than or equal to current version' do
    store = {}
    catalog = RedminePluginCheck::TargetVersionCatalog.new(
      :settings_store => store,
      :fetcher => lambda { |_url| '<a href="3.3.2/">3.3.2/</a><a href="3.3.3/">3.3.3/</a><a href="6.1.3/">6.1.3/</a>' },
      :now => lambda { Time.local(2026, 7, 1, 12, 0, 0) }
    )

    assert_equal ['3.3.3', '6.1.3'], catalog.versions_for('3.3.3.stable')
  end

  test 'uses cached versions for twenty four hours' do
    calls = 0
    store = {
      'target_redmine_versions' => '3.3.3,6.1.3',
      'target_redmine_versions_fetched_at' => '2026-07-01 12:00:00 +0900'
    }
    catalog = RedminePluginCheck::TargetVersionCatalog.new(
      :settings_store => store,
      :fetcher => lambda { |_url| calls += 1; '<a href="7.0.0/">7.0.0/</a>' },
      :now => lambda { Time.local(2026, 7, 2, 11, 59, 0) }
    )

    assert_equal ['3.3.3', '6.1.3'], catalog.versions_for('3.3.3')
    assert_equal 0, calls
  end

  test 'falls back to empty list when fetch fails' do
    catalog = RedminePluginCheck::TargetVersionCatalog.new(
      :settings_store => {},
      :fetcher => lambda { |_url| raise 'network error' }
    )

    assert_equal [], catalog.versions_for('3.3.3')
  end
end
