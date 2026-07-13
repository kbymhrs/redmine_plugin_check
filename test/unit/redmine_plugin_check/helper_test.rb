require File.expand_path('../../test_helper', File.dirname(__FILE__))

require_relative '../../../app/helpers/redmine_plugin_check_helper' unless defined?(RedminePluginCheckHelper)

class RedminePluginCheckHelperTest < ActionView::TestCase
  include RedminePluginCheckHelper

  test 'inline markdown keeps text around code spans visible' do
    html = plugin_check_inline_markdown('`requires_redmine` は `>3.3.0` 以上です。**重要**です。')

    assert_includes html, '<code>requires_redmine</code>'
    assert_includes html, '<code>&gt;3.3.0</code>'
    assert_includes html, ' は '
    assert_includes html, '<strong>重要</strong>'
    assert_includes html, 'です。'
  end

  test 'renders bold text that contains code spans' do
    html = plugin_check_inline_markdown('**Plugin Compatibility Check (`redmine_plugin_check`)**')

    assert_includes html, '<strong>Plugin Compatibility Check (<code>redmine_plugin_check</code>)</strong>'
    assert_not_includes html, '**'
  end

  test 'inline markdown escapes non markdown text' do
    html = plugin_check_inline_markdown('<script>alert(1)</script> `safe_code`')

    assert_includes html, '&lt;script&gt;alert(1)&lt;/script&gt;'
    assert_includes html, '<code>safe_code</code>'
  end
  test 'markdown preview renders pipe tables' do
    markdown = <<-MARKDOWN
| Plugin | Status | Next action |
|---|---|---|
| `redmine_mentions` | Warning | Use **core feature** |
| redmine_drafts | Risky | Check forks |
    MARKDOWN

    html = plugin_check_markdown_preview(markdown)

    assert_includes html, '<table class="plugin-check-markdown-table">'
    assert_includes html, '<thead>'
    assert_includes html, '<th>Plugin</th>'
    assert_includes html, '<td><code>redmine_mentions</code></td>'
    assert_includes html, '<strong>core feature</strong>'
    assert_not_includes html, '|---|---|---|'
  end
end
