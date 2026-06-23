class RedmineUpgradeAdvisorController < ApplicationController
  prepend_view_path File.expand_path('../../views', __FILE__)

  layout 'admin'
  helper RedmineUpgradeAdvisorHelper

  before_filter :require_admin

  def index
    @target_version = params[:target_version].to_s.strip
    @check_latest = params[:check_latest].to_s == '1'
    @report = RedmineUpgradeAdvisor::Analyzer.new(
      :target_version => @target_version,
      :check_latest => @check_latest
    ).call

    respond_to do |format|
      format.html
      format.csv do
        send_data csv_export(@report),
                  :filename => csv_filename,
                  :type => 'text/csv; charset=utf-8'
      end
    end
  end

  private

  def csv_export(report)
    require 'csv'

    CSV.generate(:headers => true) do |csv|
      csv << [
        'status',
        'plugin_id',
        'name',
        'version',
        'latest_version',
        'latest_version_source',
        'latest_version_error',
        'author',
        'last_modified_at',
        'requires_redmine',
        'requires_redmine_satisfied',
        'requires_redmine_lower_bound_only',
        'target_major_jump',
        'redmine_condition_in_init',
        'has_migrations',
        'has_gemfile',
        'compatibility_findings',
        'notes'
      ]

      report.plugins.each do |plugin|
        csv << [
          plugin.status,
          plugin.id,
          plugin.name,
          plugin.version,
          plugin.latest_version,
          plugin.latest_version_source,
          localized_latest_version_error(plugin.latest_version_error),
          plugin.author,
          formatted_time(plugin.last_modified_at),
          plugin.requires_redmine,
          plugin.requires_redmine_satisfied,
          plugin.requires_redmine_lower_bound_only,
          plugin.target_major_jump,
          plugin.redmine_condition_in_init,
          plugin.has_migrations,
          plugin.has_gemfile,
          localized_findings(plugin.compatibility_findings).join(' | '),
          localized_notes(plugin.notes).join(' | ')
        ]
      end
    end
  end

  def localized_notes(notes)
    notes.map do |note|
      I18n.t("redmine_upgrade_advisor.notes.#{note}", :default => note.to_s)
    end
  end

  def localized_findings(findings)
    findings.map do |finding|
      label = I18n.t("redmine_upgrade_advisor.findings.#{finding.key}", :default => finding.key.to_s)
      "#{label} (#{finding.path})"
    end
  end

  def localized_latest_version_error(error)
    return nil if error.blank?

    I18n.t("redmine_upgrade_advisor.latest_version_errors.#{error}", :default => error.to_s)
  end

  def formatted_time(value)
    value && value.strftime('%Y-%m-%d %H:%M:%S %z')
  end

  def csv_filename
    timestamp = Time.zone.now.strftime('%Y%m%d%H%M%S')
    "plugin_check_#{timestamp}.csv"
  end
end
