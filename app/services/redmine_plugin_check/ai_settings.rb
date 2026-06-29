module RedminePluginCheck
  class AiSettings
    DEFAULTS = {
      'ai_enabled' => '0',
      'ai_provider_label' => 'OpenAI compatible',
      'ai_endpoint' => 'https://api.openai.com/v1/chat/completions',
      'ai_api_key' => '',
      'ai_api_key_env' => 'REDMINE_PLUGIN_CHECK_AI_API_KEY',
      'ai_model' => 'gpt-4.1-mini',
      'ai_timeout_seconds' => '60',
      'ai_max_prompt_characters' => '30000',
      'ai_system_prompt' => 'You are an expert Redmine upgrade advisor. Analyze the plugin compatibility report and return concrete actions for the administrator.'
    }.freeze

    def initialize(settings = nil, env = ENV)
      @settings = DEFAULTS.merge(normalize_settings(settings || plugin_settings))
      @env = env
    end

    def enabled?
      value('ai_enabled') == '1'
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
      value('ai_system_prompt')
    end

    private

    attr_reader :settings, :env

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
  end
end