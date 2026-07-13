module RedminePluginCheckHelper
  def plugin_check_status_label(status)
    css_class =
      case status.to_s
      when 'OK'
        'status-ok'
      when 'Warning'
        'status-warning'
      when 'Risky'
        'status-risky'
      else
        'status-unknown'
      end

    content_tag(:span, status, :class => "plugin-check-status #{css_class}")
  end

  def plugin_check_name_label(plugin)
    name = plugin.name.presence || '-'
    return name unless plugin.latest_version_source.present?

    link_to(name, plugin.latest_version_source,
            :target => '_blank',
            :rel => 'noopener noreferrer')
  end
  def plugin_check_status_filter_options
    [
      [l(:label_status_filter_all), 'all'],
      [l(:label_status_filter_needs_review), 'needs_review'],
      ['Risky', 'Risky'],
      ['Warning', 'Warning'],
      ['Unknown', 'Unknown'],
      ['OK', 'OK']
    ]
  end

  def plugin_check_boolean_label(value)
    value ? l(:general_text_Yes) : l(:general_text_No)
  end

  def plugin_check_requires_label(plugin)
    return plugin.requires_redmine.presence || '-' if plugin.requires_redmine_satisfied.nil?

    label = plugin.requires_redmine_satisfied ? 'OK' : 'Warning'
    "#{plugin.requires_redmine} (#{label})"
  end

  def plugin_check_latest_version_label(plugin, checked)
    return '-' unless checked

    if plugin.latest_version.present?
      return link_to(plugin.latest_version, plugin.latest_version_source,
                     :target => '_blank',
                     :rel => 'noopener noreferrer') if plugin.latest_version_source.present?

      return plugin.latest_version
    end

    error = plugin.latest_version_error.presence || :version_unavailable
    I18n.t("redmine_plugin_check.latest_version_errors.#{error}", :default => '-')
  end

  def plugin_check_column_header(label_key, help_key)
    content_tag(:span,
                l(label_key),
                :class => 'plugin-check-column-help',
                :title => plugin_check_column_help_text(help_key))
  end

  def plugin_check_column_help_items
    [
      [:field_status, :status],
      [:field_name, :name],
      [:field_identifier, :identifier],
      [:field_version, :version],
      [:label_latest_version, :latest_version],
      [:field_author, :author],
      [:label_last_modified_at, :last_modified_at],
      [:label_requires_redmine, :requires_redmine],
      [:label_requires_redmine_lower_bound_only, :requires_redmine_lower_bound_only],
      [:label_target_major_jump, :target_major_jump],
      [:label_redmine_condition_in_init, :redmine_condition_in_init],
      [:label_has_migrations, :has_migrations],
      [:label_has_gemfile, :has_gemfile],
      [:label_compatibility_findings, :compatibility_findings],
      [:label_primary_reasons, :primary_reasons],
      [:label_notes, :notes]
    ]
  end

  def plugin_check_column_help_text(help_key)
    I18n.t("redmine_plugin_check.column_help.#{help_key}", :default => '')
  end

  def plugin_check_reasons_label(reasons)
    return '-' if reasons.blank?

    content_tag(:ul, :class => 'plugin-check-primary-reasons') do
      reasons.map do |reason|
        content_tag(:li, plugin_check_note_label(reason), :class => plugin_check_note_class(reason))
      end.join.html_safe
    end
  end

  def plugin_check_note_label(note)
    I18n.t("redmine_plugin_check.notes.#{note}", :default => note.to_s)
  end

  def plugin_check_finding_label(finding)
    label = I18n.t("redmine_plugin_check.findings.#{finding.key}", :default => finding.key.to_s)
    location = finding.line.present? ? "#{finding.path}:#{finding.line}" : finding.path
    "#{label} (#{location})"
  end

  def plugin_check_note_class(note)
    risky_notes = [
      :target_version_outside_requires_redmine,
      :legacy_breaking_patterns_detected,
      :alias_method_chain_breaking,
      :dispatcher_to_prepare_breaking,
      :require_dispatcher_breaking
    ]
    risky_notes.include?(note) ? 'plugin-check-risky-text' : nil
  end

  def plugin_check_finding_class(finding)
    finding.severity.to_s == 'risky' ? 'plugin-check-risky-text' : nil
  end

  def plugin_check_ai_analysis_available?(settings)
    settings && settings.enabled? && settings.endpoint_present? && settings.api_key_present?
  end

  def plugin_check_ai_unavailable_message(settings)
    return l(:text_ai_analysis_disabled) unless settings && settings.enabled?
    return l(:text_ai_analysis_endpoint_missing) unless settings.endpoint_present?

    l(:text_ai_analysis_api_key_missing)
  end

  def plugin_check_ai_error_message(result)
    key = result && result.error ? result.error : :request_failed
    message = I18n.t("redmine_plugin_check.ai_errors.#{key}", :default => key.to_s)
    message = "#{message} (HTTP #{result.status_code})" if result && result.status_code
    parts = [h(message)]
    details = plugin_check_ai_error_detail_labels(result)
    parts += [tag(:br), h(details.join(' / '))] if details.any?

    if key == :request_timeout
      parts += [
        tag(:br),
        link_to(l(:label_plugin_check_settings),
                plugin_settings_path(:id => 'redmine_plugin_check'),
                :class => 'icon icon-settings plugin-check-settings-button'),
        ' ',
        h(l(:text_ai_timeout_settings_hint))
      ]
    end

    safe_join(parts)
  end

  def plugin_check_ai_error_detail_labels(result)
    details = result && result.respond_to?(:details) ? result.details : nil
    return [] unless details.respond_to?(:[])

    items = []
    timeout_type = details[:timeout_type] || details['timeout_type']
    elapsed_seconds = details[:elapsed_seconds] || details['elapsed_seconds']
    prompt_characters = details[:prompt_characters] || details['prompt_characters']
    model = details[:model] || details['model']
    response_error = details[:response_error] || details['response_error']

    items << l(:text_ai_error_timeout_type, :value => timeout_type) if timeout_type.present?
    items << l(:text_ai_error_elapsed_seconds, :value => elapsed_seconds) if elapsed_seconds.present?
    items << l(:text_ai_error_prompt_characters, :value => prompt_characters) if prompt_characters.present?
    items << l(:text_ai_error_model, :value => model) if model.present?
    items << l(:text_ai_error_response, :value => response_error) if response_error.present?
    items
  end
  def plugin_check_markdown_preview(markdown)
    lines = markdown.to_s.lines.map(&:chomp)
    html = []
    list_open = false
    index = 0

    while index < lines.length
      line = lines[index]
      if line.strip.empty?
        if list_open
          html << '</ul>'
          list_open = false
        end
        index += 1
        next
      end

      if plugin_check_markdown_table_header?(line, lines[index + 1])
        if list_open
          html << '</ul>'
          list_open = false
        end
        table_lines = [line]
        index += 2
        while index < lines.length && plugin_check_markdown_table_row?(lines[index])
          table_lines << lines[index]
          index += 1
        end
        html << plugin_check_markdown_table(table_lines)
        next
      end

      heading = line.match(/\A(\#{1,4})\s+(.+)\z/)
      if heading
        if list_open
          html << '</ul>'
          list_open = false
        end
        level = [heading[1].length + 1, 5].min
        html << content_tag("h#{level}", heading[2].strip)
        index += 1
        next
      end

      item = line.match(/\A\s*[-*]\s+(.+)\z/)
      if item
        unless list_open
          html << '<ul>'
          list_open = true
        end
        html << content_tag(:li, plugin_check_inline_markdown(item[1].strip))
        index += 1
        next
      end

      if list_open
        html << '</ul>'
        list_open = false
      end
      html << content_tag(:p, plugin_check_inline_markdown(line.strip))
      index += 1
    end

    html << '</ul>' if list_open
    html.join.html_safe
  end

  def plugin_check_markdown_table_header?(header, separator)
    plugin_check_markdown_table_row?(header) && separator.to_s.strip =~ /\A\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\z/
  end

  def plugin_check_markdown_table_row?(line)
    value = line.to_s.strip
    value.start_with?('|') && value.count('|') >= 2
  end

  def plugin_check_markdown_table(lines)
    header = plugin_check_markdown_table_cells(lines.first)
    body = lines[1..-1].to_a.map { |line| plugin_check_markdown_table_cells(line) }
    column_count = header.length

    content_tag(:table, :class => 'plugin-check-markdown-table') do
      thead = content_tag(:thead) do
        content_tag(:tr) do
          header.map { |cell| content_tag(:th, plugin_check_inline_markdown(cell)) }.join.html_safe
        end
      end
      tbody = content_tag(:tbody) do
        body.map do |row|
          cells = row[0, column_count]
          cells += [''] while cells.length < column_count
          content_tag(:tr) do
            cells.map { |cell| content_tag(:td, plugin_check_inline_markdown(cell)) }.join.html_safe
          end
        end.join.html_safe
      end
      (thead + tbody).html_safe
    end
  end

  def plugin_check_markdown_table_cells(line)
    value = line.to_s.strip
    value = value[1..-1] if value.start_with?('|')
    value = value[0..-2] if value.end_with?('|')
    value.split('|').map { |cell| cell.strip }
  end

  def plugin_check_inline_markdown(text)
    plugin_check_inline_segments(text.to_s).html_safe
  end

  def plugin_check_inline_segments(text)
    text.to_s.split(/(\*\*.*?\*\*)/m).map do |part|
      bold = part.match(/\A\*\*(.*?)\*\*\z/m)
      if bold
        content_tag(:strong, plugin_check_inline_code(bold[1]).html_safe).to_s
      else
        plugin_check_inline_code(part)
      end
    end.join
  end

  def plugin_check_inline_code(text)
    text.to_s.split(/(`[^`]*`)/).map do |part|
      code = part.match(/\A`(.*)`\z/m)
      if code
        content_tag(:code, code[1]).to_s
      else
        ERB::Util.html_escape(part).to_s
      end
    end.join
  end
end


