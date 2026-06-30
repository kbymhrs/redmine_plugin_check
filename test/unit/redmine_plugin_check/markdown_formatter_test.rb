require File.expand_path('../../test_helper', File.dirname(__FILE__))

require_relative '../../../app/services/redmine_plugin_check/markdown_formatter' unless defined?(RedminePluginCheck::MarkdownFormatter)

class RedminePluginCheckMarkdownFormatterTest < ActiveSupport::TestCase
  test 'removes wrapper fences and normalizes spacing around headings and lists' do
    markdown = <<-TEXT
```markdown
Intro paragraph
### Heading
* **Item one**: body
* **Item two**: body
---
#### Next
1. Numbered item
```
TEXT

    formatted = RedminePluginCheck::MarkdownFormatter.new(markdown).call

    assert !formatted.include?('```'), 'wrapper fences should be removed'
    assert_includes formatted, "Intro paragraph\n\n### Heading\n\n- **Item one**: body"
    assert_includes formatted, "- **Item two**: body\n\n---\n\n#### Next\n\n1. Numbered item"
    assert formatted.end_with?("\n"), 'formatted markdown should end with one newline'
  end

  test 'keeps indented nested list text readable' do
    markdown = "- parent\n    * child\nplain"

    formatted = RedminePluginCheck::MarkdownFormatter.new(markdown).call

    assert_includes formatted, "- parent\n    - child"
    assert_includes formatted, "\n\nplain"
  end
end