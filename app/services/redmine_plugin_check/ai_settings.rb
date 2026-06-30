module RedminePluginCheck
  class AiSettings
    DEFAULT_SYSTEM_PROMPT_ENGLISH = 'You are an expert Redmine upgrade advisor. Analyze the plugin compatibility report and return concrete actions for the administrator.'.freeze
    DEFAULT_SYSTEM_PROMPT_JAPANESE = 'あなたは Redmine アップグレード支援の専門家です。プラグイン互換性レポートを分析し、管理者が実行すべき具体的な対応を日本語で返してください。'.freeze

    PROVIDER_PRESETS = {
      'custom' => {
        'label' => 'Custom',
        'provider_label' => 'Custom OpenAI compatible',
        'endpoint' => 'https://api.example.com/v1/chat/completions',
        'api_key_env' => 'REDMINE_PLUGIN_CHECK_AI_API_KEY',
        'model' => 'model-name'
      },
      'openai' => {
        'label' => 'OpenAI',
        'provider_label' => 'OpenAI',
        'endpoint' => 'https://api.openai.com/v1/chat/completions',
        'api_key_env' => 'REDMINE_PLUGIN_CHECK_OPENAI_API_KEY',
        'model' => 'gpt-4.1-mini'
      },
      'gemini' => {
        'label' => 'Gemini',
        'provider_label' => 'Gemini',
        'endpoint' => 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent',
        'api_key_env' => 'REDMINE_PLUGIN_CHECK_GEMINI_API_KEY',
        'model' => 'gemini-1.5-flash'
      },
      'claude' => {
        'label' => 'Claude',
        'provider_label' => 'Claude',
        'endpoint' => 'https://api.anthropic.com/v1/messages',
        'api_key_env' => 'REDMINE_PLUGIN_CHECK_CLAUDE_API_KEY',
        'model' => 'claude-3-5-haiku-latest'
      },
      'azure_openai' => {
        'label' => 'Azure OpenAI',
        'provider_label' => 'Azure OpenAI',
        'endpoint' => 'https://YOUR_RESOURCE.openai.azure.com/openai/deployments/YOUR_DEPLOYMENT/chat/completions?api-version=2024-02-15-preview',
        'api_key_env' => 'REDMINE_PLUGIN_CHECK_AZURE_OPENAI_API_KEY',
        'model' => 'YOUR_DEPLOYMENT'
      }
    }.freeze

    DEFAULTS = {
      'ai_enabled' => '0',
      'ai_provider_preset' => 'openai',
      'ai_provider_label' => PROVIDER_PRESETS['openai']['provider_label'],
      'ai_endpoint' => PROVIDER_PRESETS['openai']['endpoint'],
      'ai_api_key' => '',
      'ai_api_key_env' => 'REDMINE_PLUGIN_CHECK_AI_API_KEY',
      'ai_model' => PROVIDER_PRESETS['openai']['model'],
      'ai_timeout_seconds' => '60',
      'ai_max_prompt_characters' => '30000',
      'ai_system_prompt' => ''
    }.freeze

    def self.provider_preset_options
      %w[openai gemini claude azure_openai custom].map do |key|
        [PROVIDER_PRESETS[key]['label'], key]
      end
    end

    def self.provider_preset(key)
      PROVIDER_PRESETS[key.to_s] || PROVIDER_PRESETS['custom']
    end

    def initialize(settings = nil, env = ENV, locale = nil)
      @settings = DEFAULTS.merge(normalize_settings(settings || plugin_settings))
      @env = env
      @locale = locale
    end

    def enabled?
      value('ai_enabled') == '1'
    end

    def provider_preset
      preset = value('ai_provider_preset')
      PROVIDER_PRESETS.key?(preset) ? preset : 'custom'
    end

    def provider_label
      value('ai_provider_label')
    end

    def endpoint
      value('ai_endpoint')
    end

    def endpoint_present?
      present?(endpoint)
    end

    def api_key
      env_value = env_api_key
      return env_value if present?(env_value)

      value('ai_api_key')
    end

    def api_key_present?
      present?(api_key)
    end

    def api_key_env
      value('ai_api_key_env')
    end

    def model
      value('ai_model')
    end

    def timeout_seconds
      positive_integer(value('ai_timeout_seconds'), DEFAULTS['ai_timeout_seconds'].to_i)
    end

    def max_prompt_characters
      positive_integer(value('ai_max_prompt_characters'), DEFAULTS['ai_max_prompt_characters'].to_i)
    end

    def system_prompt
      prompt = value('ai_system_prompt')
      return localized_default_system_prompt if default_system_prompt?(prompt)

      prompt
    end

    private

    attr_reader :settings, :env, :locale

    def plugin_settings
      if defined?(Setting) && Setting.respond_to?(:plugin_redmine_plugin_check)
        Setting.plugin_redmine_plugin_check || {}
      else
        {}
      end
    end

    def normalize_settings(source)
      normalized = {}
      source.each { |key, value| normalized[key.to_s] = value } if source.respond_to?(:each)
      normalized
    end

    def value(key)
      settings[key].to_s.strip
    end

    def env_api_key
      key = api_key_env
      return nil unless present?(key)

      env[key].to_s.strip
    end

    def positive_integer(value, default)
      integer = value.to_i
      integer > 0 ? integer : default
    end

    def present?(value)
      !value.to_s.strip.empty?
    end

    def default_system_prompt?(prompt)
      !present?(prompt) ||
        prompt == DEFAULT_SYSTEM_PROMPT_ENGLISH ||
        prompt == DEFAULT_SYSTEM_PROMPT_JAPANESE
    end

    def localized_default_system_prompt
      default = japanese_locale? ? DEFAULT_SYSTEM_PROMPT_JAPANESE : DEFAULT_SYSTEM_PROMPT_ENGLISH
      return default unless defined?(I18n)

      I18n.t('redmine_plugin_check.ai.default_system_prompt', :locale => current_locale, :default => default)
    end

    def japanese_locale?
      current_locale.to_s.downcase.start_with?('ja')
    end

    def current_locale
      return locale if locale
      return I18n.locale if defined?(I18n) && I18n.respond_to?(:locale)

      nil
    end
  end
end

