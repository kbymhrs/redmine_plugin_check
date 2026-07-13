module RedminePluginCheck
  class AiMarkdownReport
    SECRET_PATTERNS = [
      [/((?:api[_-]?key|token|secret|password)\s*[=:]\s*)[^\s&]+/i, '\\1[REDACTED]'],
      [/(Authorization:\s*Bearer\s+)[A-Za-z0-9._\-]+/i, '\\1[REDACTED]'],
      [/\bsk-[A-Za-z0-9_\-]{10,}\b/, '[REDACTED]']
    ].freeze

    def initialize(report, plugins, options = {})
      @report = report
      @plugins = Array(plugins)
      @generated_at = options[:generated_at] || Time.zone.now
    end

    def call
      redact(build_lines.join("\n"))
    end

    private

    attr_reader :report, :plugins, :generated_at

    def build_lines
      lines = []
      lines << "# #{markdown_text(:title)}"
      lines << ''
      append_summary(lines)
      append_priority_plugins(lines)
      append_plugin_details(lines)
      append_ai_request(lines)
      lines
    end

    def append_summary(lines)
      lines << "## #{markdown_text(:summary)}"
      lines << ''
      lines << "- #{markdown_text(:generated_at)}: #{formatted_time(generated_at)}"
      lines << "- #{markdown_text(:current_redmine_version)}: #{text(report.redmine_version)}"
      lines << "- #{markdown_text(:target_redmine_version)}: #{text(report.target_version)}"
      lines << "- #{markdown_text(:ruby_version)}: #{text(report.ruby_version)}"
      lines << "- #{markdown_text(:rails_version)}: #{text(report.rails_version)}"
      lines << "- #{markdown_text(:plugin_count)}: #{plugins.size}"
      status_counts.each do |status, count|
        lines << "- #{status}: #{count}"
      end
      lines << ''
    end

    def append_priority_plugins(lines)
      priority_plugins = plugins.select { |plugin| %w[Risky Warning Unknown].include?(plugin.status.to_s) }

      lines << "## #{markdown_text(:priority_review_list)}"
      lines << ''
      if priority_plugins.empty?
        lines << "- #{markdown_text(:no_priority_plugins)}"
      else
        priority_plugins.each do |plugin|
          reasons = localized_notes(plugin.primary_reasons)
          lines << "- #{plugin_title(plugin)}: #{reasons.empty? ? '-' : reasons.join('; ')}"
        end
      end
      lines << ''
    end

    def append_plugin_details(lines)
      lines << "## #{markdown_text(:plugin_details)}"
      lines << ''
      plugins.each do |plugin|
        lines << "### #{plugin_title(plugin)}"
        lines << ''
        lines << "- #{markdown_text(:status)}: #{text(plugin.status)}"
        lines << "- #{markdown_text(:name)}: #{text(plugin.name)}"
        lines << "- #{markdown_text(:plugin_id)}: #{text(plugin.id)}"
        lines << "- #{markdown_text(:version)}: #{text(plugin.version)}"
        lines << "- #{markdown_text(:latest_version)}: #{text(plugin.latest_version)}"
        lines << "- #{markdown_text(:latest_version_source)}: #{text(plugin.latest_version_source)}"
        lines << "- #{markdown_text(:latest_version_error)}: #{localized_latest_version_error(plugin.latest_version_error)}"
        lines << "- #{markdown_text(:author)}: #{text(plugin.author)}"
        lines << "- #{markdown_text(:last_modified_at)}: #{formatted_time(plugin.last_modified_at)}"
        lines << "- #{markdown_text(:requires_redmine)}: #{text(plugin.requires_redmine)}"
        lines << "- #{markdown_text(:requires_redmine_satisfied)}: #{boolean_text(plugin.requires_redmine_satisfied)}"
        lines << "- #{markdown_text(:requires_redmine_lower_bound_only)}: #{boolean_text(plugin.requires_redmine_lower_bound_only)}"
        lines << "- #{markdown_text(:target_major_jump)}: #{boolean_text(plugin.target_major_jump)}"
        lines << "- #{markdown_text(:redmine_version_condition_in_init)}: #{boolean_text(plugin.redmine_condition_in_init)}"
        lines << "- #{markdown_text(:has_migrations)}: #{boolean_text(plugin.has_migrations)}"
        lines << "- #{markdown_text(:has_gemfile)}: #{boolean_text(plugin.has_gemfile)}"
        lines << "- #{markdown_text(:primary_reasons)}: #{list_text(localized_notes(plugin.primary_reasons))}"
        lines << "- #{markdown_text(:notes)}: #{list_text(localized_notes(plugin.notes))}"
        lines << "- #{markdown_text(:compatibility_findings)}:"
        append_findings(lines, plugin.compatibility_findings)
        lines << ''
      end
    end

    def append_findings(lines, findings)
      if Array(findings).empty?
        lines << '  - -'
        return
      end

      Array(findings).each do |finding|
        lines << "  - #{localized_finding(finding)}"
      end
    end

    def append_ai_request(lines)
      lines << "## #{markdown_text(:request_for_ai)}"
      lines << ''
      lines << markdown_text(:request).strip
      lines << ''
    end

    def markdown_text(key)
      I18n.t("redmine_plugin_check.ai_markdown.#{key}")
    end

    def status_counts
      counts = {}
      %w[Risky Warning Unknown OK].each { |status| counts[status] = 0 }
      plugins.each do |plugin|
        status = plugin.status.to_s
        counts[status] ||= 0
        counts[status] += 1
      end
      counts
    end

    def plugin_title(plugin)
      "#{text(plugin.status)} - #{text(plugin.name)} (`#{text(plugin.id)}`)"
    end

    def list_text(items)
      items.empty? ? '-' : items.join('; ')
    end

    def localized_notes(notes)
      Array(notes).map do |note|
        I18n.t("redmine_plugin_check.notes.#{note}", :default => note.to_s)
      end
    end

    def localized_finding(finding)
      label = I18n.t("redmine_plugin_check.findings.#{finding.key}", :default => finding.key.to_s)
      location = finding.line ? "#{finding.path}:#{finding.line}" : finding.path
      "#{label} (#{location})"
    end

    def localized_latest_version_error(error)
      return '-' if empty_text?(error)

      I18n.t("redmine_plugin_check.latest_version_errors.#{error}", :default => error.to_s)
    end

    def boolean_text(value)
      return '-' if value.nil?

      value ? I18n.t(:general_text_Yes, :default => 'Yes') : I18n.t(:general_text_No, :default => 'No')
    end

    def formatted_time(value)
      return '-' if value.nil?

      value.strftime('%Y-%m-%d %H:%M:%S')
    end

    def text(value)
      value = value.to_s.strip
      value.empty? ? '-' : value
    end

    def empty_text?(value)
      value.to_s.strip.empty?
    end

    def redact(content)
      SECRET_PATTERNS.inject(content) do |text, pattern|
        regexp, replacement = pattern
        text.gsub(regexp, replacement)
      end
    end
  end
end
