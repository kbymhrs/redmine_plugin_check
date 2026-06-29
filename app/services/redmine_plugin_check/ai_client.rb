require 'json'
require 'net/http'
require 'openssl'
require 'timeout'
require 'uri'

module RedminePluginCheck
  class AiClient
    Result = Struct.new(:success, :content, :error, :status_code)

    USER_AGENT = 'RedminePluginCheck/0.1.1'.freeze

    def initialize(settings)
      @settings = settings
    end

    def call(markdown)
      return Result.new(false, nil, :ai_disabled, nil) unless settings.enabled?
      return Result.new(false, nil, :endpoint_missing, nil) unless settings.endpoint_present?
      return Result.new(false, nil, :api_key_missing, nil) unless settings.api_key_present?
      return Result.new(false, nil, :model_missing, nil) unless present?(settings.model)

      response = post_json(URI.parse(settings.endpoint), request_payload(markdown))
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

    private

    attr_reader :settings

    def request_payload(markdown)
      JSON.generate(
        'model' => settings.model,
        'messages' => [
          { 'role' => 'system', 'content' => settings.system_prompt },
          { 'role' => 'user', 'content' => limited_prompt(markdown) }
        ]
      )
    end

    def limited_prompt(markdown)
      text = markdown.to_s
      limit = settings.max_prompt_characters
      return text if text.length <= limit

      note = "\n\n[TRUNCATED: The AI prompt exceeded #{limit} characters and was cut before sending.]"
      return note[0, limit] if limit <= note.length

      text[0, limit - note.length] + note
    end

    def extract_content(body)
      data = JSON.parse(body.to_s)
      choices = data['choices']
      return nil unless choices.is_a?(Array) && choices.first.is_a?(Hash)

      message = choices.first['message']
      return message['content'] if message.is_a?(Hash)

      choices.first['text']
    end

    def post_json(uri, body)
      response = nil
      Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https',
                                      :open_timeout => settings.timeout_seconds,
                                      :read_timeout => settings.timeout_seconds) do |http|
        request = Net::HTTP::Post.new(uri.request_uri)
        request['User-Agent'] = USER_AGENT
        request['Content-Type'] = 'application/json'
        request['Accept'] = 'application/json'
        request['Authorization'] = "Bearer #{settings.api_key}"
        request.body = body
        response = http.request(request)
      end
      response
    end

    def present?(value)
      !value.to_s.strip.empty?
    end
  end
end