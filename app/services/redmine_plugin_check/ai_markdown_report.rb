module RedminePluginCheck
  class AiMarkdownReport
    DEFAULT_REQUEST = <<-TEXT
あなたは Redmine プラグイン移行支援の専門家です。
以下の診断結果をもとに、Redmine を現在のバージョンから移行先バージョンへアップグレードするために必要な作業を分析してください。

出力してほしい内容:
1. 全体の移行リスク
2. 優先して対応すべきプラグイン
3. 各プラグインごとの推奨対応
4. 削除・更新・代替検討が必要なもの
5. 追加調査が必要なもの
6. 実施順序
7. 管理者向けの簡潔な結論
TEXT
    DEFAULT_REQUEST.freeze

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
      lines << '# Redmine Plugin Compatibility AI Report'
      lines << ''
      append_summary(lines)
      append_priority_plugins(lines)
      append_plugin_details(lines)
      append_ai_request(lines)
      lines
    end

    def append_summary(lines)
      lines << '## Summary'
      lines << ''
      lines << "- Generated at: #{formatted_time(generated_at)}"
      lines << "- Current Redmine version: #{text(report.redmine_version)}"
      lines << "- Target Redmine version: #{text(report.target_version)}"
      lines << "- Ruby version: #{text(report.ruby_version)}"
      lines << "- Rails version: #{text(report.rails_version)}"
      lines << "- Plugin count: #{plugins.size}"
      status_counts.each do |status, count|
        lines << "- #{status}: #{count}"
      end
      lines << ''
    end

    def append_priority_plugins(lines)
      priority_plugins = plugins.select { |plugin| %w[Risky Warning Unknown].include?(plugin.status.to_s) }

      lines << '## Priority Review List'
      lines << ''
      if priority_plugins.empty?
        lines << '- No Risky, Warning, or Unknown plugins in the selected result.'
      else
        priority_plugins.each do |plugin|
          reasons = localized_notes(plugin.primary_reasons)
          lines << "- #{plugin_title(plugin)}: #{reasons.empty? ? '-' : reasons.join('; ')}"
        end
      end
      lines << ''
    end

    def append_plugin_details(lines)
      lines << '## Plugin Details'
      lines << ''
      plugins.each do |plugin|
        lines << "### #{plugin_title(plugin)}"
        lines << ''
        lines << "- Status: #{text(plugin.status)}"
        lines << "- Name: #{text(plugin.name)}"
        lines << "- Plugin ID: #{text(plugin.id)}"
        lines << "- Version: #{text(plugin.version)}"
        lines << "- Latest version: #{text(plugin.latest_version)}"
        lines << "- Latest version source: #{text(plugin.latest_version_source)}"
        lines << "- Latest version error: #{localized_latest_version_error(plugin.latest_version_error)}"
        lines << "- Author: #{text(plugin.author)}"
        lines << "- Last modified at: #{formatted_time(plugin.last_modified_at)}"
        lines << "- requires_redmine: #{text(plugin.requires_redmine)}"
        lines << "- requires_redmine satisfied: #{boolean_text(plugin.requires_redmine_satisfied)}"
        lines << "- requires_redmine lower bound only: #{boolean_text(plugin.requires_redmine_lower_bound_only)}"
        lines << "- Target major jump: #{boolean_text(plugin.target_major_jump)}"
        lines << "- Redmine version condition in init.rb: #{boolean_text(plugin.redmine_condition_in_init)}"
        lines << "- Has db/migrate: #{boolean_text(plugin.has_migrations)}"
        lines << "- Has Gemfile: #{boolean_text(plugin.has_gemfile)}"
        lines << "- Primary reasons: #{list_text(localized_notes(plugin.primary_reasons))}"
        lines << "- Notes: #{list_text(localized_notes(plugin.notes))}"
        lines << '- Compatibility findings:'
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
      lines << '## Request For AI'
      lines << ''
      lines << DEFAULT_REQUEST.strip
      lines << ''
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

      value.strftime('%Y-%m-%d %H:%M:%S %z')
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
