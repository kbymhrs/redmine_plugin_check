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
      [:label_notes, :notes]
    ]
  end

  def plugin_check_column_help_text(help_key)
    I18n.t("redmine_plugin_check.column_help.#{help_key}", :default => '')
  end

  def plugin_check_note_label(note)
    I18n.t("redmine_plugin_check.notes.#{note}", :default => note.to_s)
  end

  def plugin_check_finding_label(finding)
    label = I18n.t("redmine_plugin_check.findings.#{finding.key}", :default => finding.key.to_s)
    "#{label} (#{finding.path})"
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
end
