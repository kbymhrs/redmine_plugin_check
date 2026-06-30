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

  test 'inline markdown escapes non markdown text' do
    html = plugin_check_inline_markdown('<script>alert(1)</script> `safe_code`')

    assert_includes html, '&lt;script&gt;alert(1)&lt;/script&gt;'
    assert_includes html, '<code>safe_code</code>'
  end
end