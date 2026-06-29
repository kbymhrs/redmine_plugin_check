require File.expand_path('../../test_helper', File.dirname(__FILE__))

require_relative '../../../app/services/redmine_plugin_check/ai_markdown_report' unless defined?(RedminePluginCheck::AiMarkdownReport)

class RedminePluginCheckAiMarkdownReportTest < ActiveSupport::TestCase
  FakeReport = Struct.new(:redmine_version, :ruby_version, :rails_version, :target_version, :plugins)
  FakePlugin = Struct.new(
    :id,
    :name,
    :version,
    :latest_version,
    :latest_version_source,
    :latest_version_error,
    :author,
    :last_modified_at,
    :requires_redmine,
    :requires_redmine_satisfied,
    :requires_redmine_lower_bound_only,
    :target_major_jump,
    :redmine_condition_in_init,
    :has_migrations,
    :has_gemfile,
    :primary_reasons,
    :compatibility_findings,
    :status,
    :notes
  )
  FakeFinding = Struct.new(:key, :path, :line, :severity)

  test 'renders summary priority list plugin details and ai request' do
    plugin = fake_plugin(
      :status => 'Risky',
      :primary_reasons => [:target_version_outside_requires_redmine],
      :notes => [:requires_redmine_lower_bound_only],
      :compatibility_findings => [FakeFinding.new(:alias_method_chain, 'lib/patch.rb', 12, 'risky')]
    )
    report = fake_report([plugin])

    markdown = RedminePluginCheck::AiMarkdownReport.new(report, [plugin], :generated_at => Time.utc(2026, 6, 29, 0, 0, 0)).call

    assert_includes markdown, '# Redmine Plugin Compatibility AI Report'
    assert_includes markdown, '- Target Redmine version: 6.0.0'
    assert_includes markdown, '- Risky: 1'
    assert_includes markdown, '## Priority Review List'
    assert_includes markdown, 'Risky - Legacy Plugin (`legacy_plugin`)'
    assert_includes markdown, 'alias_method_chain (lib/patch.rb:12)'
    assert_includes markdown, '## Request For AI'
  end

  test 'redacts likely secrets before returning markdown' do
    plugin = fake_plugin(
      :latest_version_source => 'https://example.test/releases?token=super-secret',
      :notes => ['Authorization: Bearer sk-secret1234567890']
    )
    report = fake_report([plugin])

    markdown = RedminePluginCheck::AiMarkdownReport.new(report, [plugin], :generated_at => Time.utc(2026, 6, 29, 0, 0, 0)).call

    assert_includes markdown, '[REDACTED]'
    assert !markdown.include?('super-secret'), 'token value should be redacted'
    assert !markdown.include?('sk-secret1234567890'), 'OpenAI-like key should be redacted'
  end

  private

  def fake_report(plugins)
    FakeReport.new('3.3.3', '2.3.3', '4.2.7.1', '6.0.0', plugins)
  end

  def fake_plugin(attrs = {})
    values = {
      :id => 'legacy_plugin',
      :name => 'Legacy Plugin',
      :version => '1.0.0',
      :latest_version => '2.0.0',
      :latest_version_source => 'https://github.com/example/legacy_plugin',
      :latest_version_error => nil,
      :author => 'ACME',
      :last_modified_at => Time.utc(2026, 6, 1, 12, 0, 0),
      :requires_redmine => 'version_or_higher: "3.3.0"',
      :requires_redmine_satisfied => true,
      :requires_redmine_lower_bound_only => true,
      :target_major_jump => true,
      :redmine_condition_in_init => false,
      :has_migrations => false,
      :has_gemfile => false,
      :primary_reasons => [],
      :compatibility_findings => [],
      :status => 'OK',
      :notes => []
    }
    attrs.each { |key, value| values[key] = value }
    FakePlugin.new(
      values[:id],
      values[:name],
      values[:version],
      values[:latest_version],
      values[:latest_version_source],
      values[:latest_version_error],
      values[:author],
      values[:last_modified_at],
      values[:requires_redmine],
      values[:requires_redmine_satisfied],
      values[:requires_redmine_lower_bound_only],
      values[:target_major_jump],
      values[:redmine_condition_in_init],
      values[:has_migrations],
      values[:has_gemfile],
      values[:primary_reasons],
      values[:compatibility_findings],
      values[:status],
      values[:notes]
    )
  end
end