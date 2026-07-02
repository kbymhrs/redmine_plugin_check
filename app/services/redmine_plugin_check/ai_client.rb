require 'json'
require 'net/http'
require 'openssl'
require 'timeout'
require 'uri'

module RedminePluginCheck
  class AiClient
    Result = Struct.new(:success, :content, :error, :status_code)

    USER_AGENT = 'RedminePluginCheck/0.1.1'.freeze
    TEST_PROMPT = 'Reply with OK only.'.freeze
    GEMINI_MODELS_ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models'.freeze
    CLAUDE_MODELS_ENDPOINT = 'https://api.anthropic.com/v1/models'.freeze

    def initialize(settings)
      @settings = settings
    end

    def call(markdown, options = {})
      return Result.new(false, nil, :ai_disabled, nil) unless options[:ignore_enabled] || settings.enabled?
      return Result.new(false, nil, :endpoint_missing, nil) unless settings.endpoint_present?
      return Result.new(false, nil, :api_key_missing, nil) unless settings.api_key_present?
      return Result.new(false, nil, :model_missing, nil) unless present?(settings.model)

      response = post_json(api_uri, request_payload(markdown))
      status_code = response.code.to_i
      return Result.new(false, nil, :http_error, status_code) unless status_code >= 200 && status_code < 300

      content = extract_content(response.body)
      return Result.new(true, content, nil, status_code) if present?(content)

      Result.new(false, nil, :response_format_error, status_code)
    rescue JSON::ParserError
      Result.new(false, nil, :json_parse_error, nil)
    rescue Timeout::Error
      Result.new(false, nil, :request_timeout, nil)
    rescue OpenSSL::SSL::SSLError
      Result.new(false, nil, :ssl_error, nil)
    rescue URI::InvalidURIError
      Result.new(false, nil, :endpoint_invalid, nil)
    rescue StandardError
      Result.new(false, nil, :request_failed, nil)
    end

    def test_connection
      call(TEST_PROMPT, :ignore_enabled => true)
    end

    def available_models
      return Result.new(false, nil, :api_key_missing, nil) unless settings.api_key_present?
      return Result.new(false, nil, :unsupported_provider, nil) unless model_list_supported?

      response = get_json(model_list_uri)
      status_code = response.code.to_i
      return Result.new(false, nil, :http_error, status_code) unless status_code >= 200 && status_code < 300

      models = extract_models(response.body)
      return Result.new(false, nil, :response_format_error, status_code) if models.empty?

      Result.new(true, models, nil, status_code)
    rescue JSON::ParserError
      Result.new(false, nil, :json_parse_error, nil)
    rescue Net::OpenTimeout, Net::ReadTimeout
      Result.new(false, nil, :request_timeout, nil)
    rescue OpenSSL::SSL::SSLError
      Result.new(false, nil, :ssl_error, nil)
    rescue URI::InvalidURIError
      Result.new(false, nil, :endpoint_invalid, nil)
    rescue StandardError
      Result.new(false, nil, :request_failed, nil)
    end

    private

    attr_reader :settings

    def request_payload(markdown)
      prompt = limited_prompt(markdown)

      case settings.provider_preset
      when 'gemini'
        gemini_payload(prompt)
      when 'claude'
        claude_payload(prompt)
      else
        chat_completions_payload(prompt)
      end
    end

    def chat_completions_payload(prompt)
      JSON.generate(
        'model' => settings.model,
        'messages' => [
          { 'role' => 'system', 'content' => settings.system_prompt },
          { 'role' => 'user', 'content' => prompt }
        ]
      )
    end

    def gemini_payload(prompt)
      JSON.generate(
        'contents' => [
          {
            'role' => 'user',
            'parts' => [
              { 'text' => settings.system_prompt + "\n\n" + prompt }
            ]
          }
        ]
      )
    end

    def claude_payload(prompt)
      JSON.generate(
        'model' => settings.model,
        'max_tokens' => 1024,
        'system' => settings.system_prompt,
        'messages' => [
          { 'role' => 'user', 'content' => prompt }
        ]
      )
    end

    def limited_prompt(markdown)
      text = markdown.to_s
      limit = settings.max_prompt_characters
      return text if text.length <= limit

      note = "\n\n" + I18n.t('redmine_plugin_check.ai.truncated_prompt', :limit => limit)
      return note[0, limit] if limit <= note.length

      text[0, limit - note.length] + note
    end

    def extract_content(body)
      data = JSON.parse(body.to_s)

      case settings.provider_preset
      when 'gemini'
        extract_gemini_content(data)
      when 'claude'
        extract_claude_content(data)
      else
        extract_chat_completions_content(data)
      end
    end

    def extract_chat_completions_content(data)
      choices = data['choices']
      return nil unless choices.is_a?(Array) && choices.first.is_a?(Hash)

      message = choices.first['message']
      return message['content'] if message.is_a?(Hash)

      choices.first['text']
    end

    def extract_gemini_content(data)
      candidates = data['candidates']
      return nil unless candidates.is_a?(Array) && candidates.first.is_a?(Hash)

      content = candidates.first['content']
      return nil unless content.is_a?(Hash)

      parts = content['parts']
      return nil unless parts.is_a?(Array)

      parts.map { |part| part.is_a?(Hash) ? part['text'] : nil }.compact.join
    end

    def extract_claude_content(data)
      content = data['content']
      return nil unless content.is_a?(Array)

      content.map { |part| part.is_a?(Hash) ? part['text'] : nil }.compact.join
    end

    def post_json(uri, body)
      response = nil
      Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https',
                                      :open_timeout => settings.timeout_seconds,
                                      :read_timeout => settings.timeout_seconds) do |http|
        request = Net::HTTP::Post.new(uri.request_uri)
        apply_headers(request)
        request.body = body
        response = http.request(request)
      end
      response
    end

    def get_json(uri)
      response = nil
      Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https',
                                      :open_timeout => settings.timeout_seconds,
                                      :read_timeout => settings.timeout_seconds) do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        apply_headers(request)
        response = http.request(request)
      end
      response
    end

    def extract_gemini_models(body)
      data = JSON.parse(body.to_s)
      models = data['models']
      return [] unless models.is_a?(Array)

      models.map do |model|
        next unless model.is_a?(Hash)

        name = model['name'].to_s.sub(%r{\Amodels/}, '')
        methods = model['supportedGenerationMethods']
        next if name.empty?
        next if methods.is_a?(Array) && !methods.include?('generateContent')

        name
      end.compact.sort
    end

    def apply_headers(request)
      request['User-Agent'] = USER_AGENT
      request['Content-Type'] = 'application/json'
      request['Accept'] = 'application/json'

      case settings.provider_preset
      when 'gemini'
        request['x-goog-api-key'] = settings.api_key
      when 'claude'
        request['x-api-key'] = settings.api_key
        request['anthropic-version'] = '2023-06-01'
      when 'azure_openai'
        request['api-key'] = settings.api_key
      else
        request['Authorization'] = "Bearer #{settings.api_key}"
      end
    end

    def api_uri
      uri = URI.parse(settings.endpoint)
      return uri unless %w[openai azure_openai custom].include?(settings.provider_preset)

      path = uri.path.to_s.sub(%r{/+\z}, '')
      return uri unless path =~ %r{/v\d+\z}

      uri.path = path + '/chat/completions'
      uri
    end

    def model_list_supported?
      %w[openai gemini claude].include?(settings.provider_preset)
    end

    def model_list_uri
      case settings.provider_preset
      when 'gemini'
        URI.parse(GEMINI_MODELS_ENDPOINT)
      when 'claude'
        URI.parse(CLAUDE_MODELS_ENDPOINT)
      else
        openai_models_uri
      end
    end

    def openai_models_uri
      uri = URI.parse(settings.endpoint)
      path = uri.path.to_s.sub(%r{/+\z}, '')
      path = path.sub(%r{/chat/completions\z}, '')
      path = '/v1' if path.empty?
      uri.path = path + '/models'
      uri.query = nil
      uri
    end

    def extract_models(body)
      case settings.provider_preset
      when 'gemini'
        extract_gemini_models(body)
      when 'claude'
        extract_data_models(body, 'id')
      else
        extract_data_models(body, 'id')
      end
    end

    def extract_data_models(body, key)
      data = JSON.parse(body.to_s)
      models = data['data']
      return [] unless models.is_a?(Array)

      models.map do |model|
        model.is_a?(Hash) ? model[key].to_s : nil
      end.compact.reject(&:empty?).sort
    end

    def present?(value)
      !value.to_s.strip.empty?
    end
  end
end

