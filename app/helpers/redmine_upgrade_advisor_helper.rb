module RedmineUpgradeAdvisorHelper
  def upgrade_advisor_status_label(status)
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

    content_tag(:span, status, :class => "upgrade-advisor-status #{css_class}")
  end

  def upgrade_advisor_boolean_label(value)
    value ? l(:general_text_Yes) : l(:general_text_No)
  end

  def upgrade_advisor_requires_label(plugin)
    return plugin.requires_redmine.presence || '-' if plugin.requires_redmine_satisfied.nil?

    label = plugin.requires_redmine_satisfied ? 'OK' : 'Warning'
    "#{plugin.requires_redmine} (#{label})"
  end

  def upgrade_advisor_latest_version_label(plugin, checked)
    return '-' unless checked

    if plugin.latest_version.present?
      return link_to(plugin.latest_version, plugin.latest_version_source,
                     :target => '_blank',
                     :rel => 'noopener noreferrer') if plugin.latest_version_source.present?

      return plugin.latest_version
    end

    error = plugin.latest_version_error.presence || :version_unavailable
    I18n.t("redmine_upgrade_advisor.latest_version_errors.#{error}", :default => '-')
  end

  def upgrade_advisor_column_header(label_key, help_key)
    content_tag(:span,
                l(label_key),
                :class => 'upgrade-advisor-column-help',
                :title => upgrade_advisor_column_help_text(help_key))
  end

  def upgrade_advisor_column_help_items
    [
      [:field_status, :status],
      [:field_identifier, :identifier],
      [:field_name, :name],
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

  def upgrade_advisor_column_help_text(help_key)
    I18n.t("redmine_upgrade_advisor.column_help.#{help_key}", :default => '')
  end

  def upgrade_advisor_note_label(note)
    I18n.t("redmine_upgrade_advisor.notes.#{note}", :default => note.to_s)
  end

  def upgrade_advisor_finding_label(finding)
    label = I18n.t("redmine_upgrade_advisor.findings.#{finding.key}", :default => finding.key.to_s)
    "#{label} (#{finding.path})"
  end
end
