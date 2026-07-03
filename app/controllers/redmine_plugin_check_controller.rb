require 'time'

class RedminePluginCheckController < ApplicationController
  prepend_view_path File.expand_path('../../views', __FILE__)

  layout 'admin'
  helper RedminePluginCheckHelper

  before_action :require_admin

  def index
    load_report

    respond_to do |format|
      format.html
      format.csv do
        send_data csv_export(@plugins),
                  :filename => csv_filename,
                  :type => 'text/csv; charset=utf-8'
      end
    end
  end

  def ai_markdown
    load_report

    send_data ai_markdown_export(@plugins),
              :filename => ai_markdown_filename,
              :type => 'text/markdown; charset=utf-8'
  end

  def ai_analysis
    load_report
    @ai_analysis_requested = true

    if @target_version.blank?
      @ai_analysis_target_version_missing = true
    else
      @ai_analysis_result = RedminePluginCheck::AiClient.new(@ai_settings).call(ai_markdown_for_analysis(@plugins))
      normalize_ai_analysis_result
      save_latest_ai_analysis_result
    end

    render :index
  end


  def ai_analysis_download
    send_data format_markdown(params[:content]),
              :filename => ai_analysis_filename,
              :type => 'text/markdown; charset=utf-8'
  end

  def ai_models
    settings = RedminePluginCheck::AiSettings.new(ai_model_request_settings)
    result = RedminePluginCheck::AiClient.new(settings).available_models

    if result.success
      render :json => { :success => true, :models => result.content }
    else
      render :json => { :success => false, :message => ai_error_message(result) }, :status => :unprocessable_entity
    end
  end

  def ai_test_connection
    result = RedminePluginCheck::AiClient.new(RedminePluginCheck::AiSettings.new).test_connection

    if result.success
      flash[:notice] = l(:notice_ai_test_connection_success)
    else
      flash[:error] = l(:error_ai_test_connection_failed, :message => ai_error_message(result))
    end

    redirect_to plugin_settings_path(:id => 'redmine_plugin_check')
  end
  private

  def ai_model_request_settings
    current = {}
    saved = Setting.plugin_redmine_plugin_check if defined?(Setting) && Setting.respond_to?(:plugin_redmine_plugin_check)
    saved.each { |key, value| current[key.to_s] = value } if saved.respond_to?(:each)

    preset = params[:ai_provider_preset].to_s
    preset = 'custom' unless RedminePluginCheck::AiSettings::PROVIDER_PRESETS.key?(preset)

    current['ai_provider_preset'] = preset
    current['ai_provider_label'] = params[:ai_provider_label].to_s
    current['ai_endpoint'] = params[:ai_endpoint].to_s
    current['ai_api_key_env'] = params[:ai_api_key_env].to_s
    current['ai_timeout_seconds'] = params[:ai_timeout_seconds].to_s if params.key?(:ai_timeout_seconds)

    api_key = params[:ai_api_key].to_s
    current[RedminePluginCheck::AiSettings.api_key_setting_key(preset)] = api_key unless api_key.blank?

    model = params[:ai_model].to_s
    current[RedminePluginCheck::AiSettings.model_setting_key(preset)] = model unless model.blank?
    current
  end

  def load_report
    @target_version = params[:target_version].to_s.strip
    @check_latest = params[:check_latest].to_s == '1'
    @status_filter = normalize_status_filter(params[:status_filter])
    @show_details = params[:show_details].to_s == '1'
    @report = RedminePluginCheck::Analyzer.new(
      :target_version => @target_version,
      :check_latest => @check_latest
    ).call

    @plugins = filtered_plugins(sorted_plugins(@report.plugins))
    @target_version_options = request.format.html? ? RedminePluginCheck::TargetVersionCatalog.new.versions_for(@report.redmine_version) : []
    @ai_settings = RedminePluginCheck::AiSettings.new
    load_latest_ai_analysis_result
  end

  def normalize_status_filter(value)
    filter = value.to_s
    allowed = %w[all needs_review Risky Warning Unknown OK]
    allowed.include?(filter) ? filter : 'all'
  end

  def filtered_plugins(plugins)
    case @status_filter
    when 'needs_review'
      plugins.select { |plugin| %w[Risky Warning Unknown].include?(plugin.status.to_s) }
    when 'Risky', 'Warning', 'Unknown', 'OK'
      plugins.select { |plugin| plugin.status.to_s == @status_filter }
    else
      plugins
    end
  end

  def sorted_plugins(plugins)
    priority = { 'Risky' => 0, 'Warning' => 1, 'Unknown' => 2, 'OK' => 3 }
    plugins.sort_by { |plugin| [priority.fetch(plugin.status.to_s, 9), plugin.name.to_s.downcase, plugin.id.to_s] }
  end

  def csv_export(plugins)
    require 'csv'

    CSV.generate(:headers => true) do |csv|
      csv << csv_headers

      plugins.each do |plugin|
        csv << [
          plugin.status,
          plugin.name,
          plugin.id,
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
          localized_notes(plugin.primary_reasons).join(' | '),
          localized_notes(plugin.notes).join(' | '),
          '',
          ''
        ]
      end
    end
  end

  def csv_headers
    [
      l(:field_status),
      l(:field_name),
      l(:field_identifier),
      l(:field_version),
      l(:label_latest_version),
      l(:label_latest_version_source),
      l(:label_latest_version_error),
      l(:field_author),
      l(:label_last_modified_at),
      l(:label_requires_redmine),
      l(:label_requires_redmine_satisfied),
      l(:label_requires_redmine_lower_bound_only),
      l(:label_target_major_jump),
      l(:label_redmine_condition_in_init),
      l(:label_has_migrations),
      l(:label_has_gemfile),
      l(:label_compatibility_findings),
      l(:label_primary_reasons),
      l(:label_notes),
      l(:label_review_result),
      l(:label_action_plan)
    ]
  end

  def ai_markdown_export(plugins)
    RedminePluginCheck::AiMarkdownReport.new(@report, plugins).call
  end



  def ai_markdown_for_analysis(plugins)
    requested_at = Time.now.utc
    [
      ai_markdown_export(plugins),
      '',
      '## Analysis Run',
      "- Requested at: #{formatted_time(requested_at)}",
      "- Request ID: #{requested_at.to_i}-#{rand(1000000)}",
      '- Treat this as a fresh analysis request. Re-evaluate the report instead of reusing a previous answer.'
    ].join("\n")
  end

  def normalize_ai_analysis_result
    return unless @ai_analysis_result && @ai_analysis_result.success

    @ai_analysis_result.content = format_markdown(@ai_analysis_result.content)
  end

  def save_latest_ai_analysis_result
    return unless @ai_analysis_result && @ai_analysis_result.success

    generated_at = Time.now.utc
    RedminePluginCheck::AiSettings.save_latest_ai_analysis(@ai_analysis_result.content, generated_at)
    @latest_ai_analysis_content = @ai_analysis_result.content
    @latest_ai_analysis_generated_at = generated_at
  end

  def load_latest_ai_analysis_result
    @latest_ai_analysis_content = @ai_settings.latest_ai_analysis_content
    @latest_ai_analysis_generated_at = parse_time(@ai_settings.latest_ai_analysis_generated_at)
  end

  def format_markdown(markdown)
    RedminePluginCheck::MarkdownFormatter.new(markdown).call
  end

  def parse_time(value)
    return value if value.respond_to?(:strftime)
    return nil if value.to_s.strip.empty?

    Time.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def ai_error_message(result)
    key = result && result.error ? result.error : :request_failed
    message = I18n.t("redmine_plugin_check.ai_errors.#{key}", :default => key.to_s)
    return message unless result && result.status_code

    "#{message} (HTTP #{result.status_code})"
  end
  def localized_notes(notes)
    notes.map do |note|
      I18n.t("redmine_plugin_check.notes.#{note}", :default => note.to_s)
    end
  end

  def localized_findings(findings)
    findings.map do |finding|
      label = I18n.t("redmine_plugin_check.findings.#{finding.key}", :default => finding.key.to_s)
      location = finding.line.present? ? "#{finding.path}:#{finding.line}" : finding.path
      "#{label} (#{location})"
    end
  end

  def localized_latest_version_error(error)
    return nil if error.blank?

    I18n.t("redmine_plugin_check.latest_version_errors.#{error}", :default => error.to_s)
  end

  def formatted_time(value)
    value && value.strftime('%Y-%m-%d %H:%M:%S %z')
  end

  def csv_filename
    timestamp = Time.zone.now.strftime('%Y%m%d%H%M%S')
    "plugin_check_#{timestamp}.csv"
  end

  def ai_markdown_filename
    timestamp = Time.zone.now.strftime('%Y%m%d%H%M%S')
    "plugin_check_ai_#{timestamp}.md"
  end

  def ai_analysis_filename
    timestamp = Time.zone.now.strftime('%Y%m%d%H%M%S')
    "plugin_check_ai_analysis_#{timestamp}.md"
  end
end

