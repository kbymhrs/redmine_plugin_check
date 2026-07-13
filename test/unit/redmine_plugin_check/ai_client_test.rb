require File.expand_path('../../test_helper', File.dirname(__FILE__))

require 'json'
require_relative '../../../app/services/redmine_plugin_check/ai_settings' unless defined?(RedminePluginCheck::AiSettings)
require_relative '../../../app/services/redmine_plugin_check/ai_client' unless defined?(RedminePluginCheck::AiClient)

class RedminePluginCheckAiClientTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body)

  test 'posts chat completion payload and returns assistant content' do
    payloads = []
    client = RedminePluginCheck::AiClient.new(ai_settings)
    client.define_singleton_method(:post_json) do |_uri, body|
      payloads << JSON.parse(body)
      FakeResponse.new('200', JSON.generate('choices' => [{ 'message' => { 'content' => 'Upgrade plan' } }]))
    end

    result = client.call('plugin report')

    assert result.success
    assert_equal 'Upgrade plan', result.content
    assert_equal 'gpt-test', payloads.first['model']
    assert_equal 'plugin report', payloads.first['messages'].last['content']
    assert_equal 12000, payloads.first['max_tokens']
  end

  test 'returns api key missing before sending request' do
    client = RedminePluginCheck::AiClient.new(ai_settings('ai_api_key' => '', 'ai_api_key_env' => ''))
    called = false
    client.define_singleton_method(:post_json) do |_uri, _body|
      called = true
      FakeResponse.new('200', '{}')
    end

    result = client.call('plugin report')

    assert !result.success
    assert_equal :api_key_missing, result.error
    assert_equal false, called
  end

  test 'truncates prompt to configured maximum characters' do
    payloads = []
    client = RedminePluginCheck::AiClient.new(ai_settings('ai_max_prompt_characters' => '160'))
    client.define_singleton_method(:post_json) do |_uri, body|
      payloads << JSON.parse(body)
      FakeResponse.new('200', JSON.generate('choices' => [{ 'message' => { 'content' => 'Short plan' } }]))
    end

    previous_locale = I18n.locale
    begin
      I18n.locale = :en
      result = client.call('x' * 500)
      sent_prompt = payloads.first['messages'].last['content']

      assert result.success
      assert sent_prompt.length <= 160
      assert_includes sent_prompt, 'TRUNCATED'
    ensure
      I18n.locale = previous_locale
    end
  end

  test 'classifies invalid response shape' do
    client = RedminePluginCheck::AiClient.new(ai_settings)
    client.define_singleton_method(:post_json) do |_uri, _body|
      FakeResponse.new('200', JSON.generate('choices' => []))
    end

    result = client.call('plugin report')

    assert !result.success
    assert_equal :response_format_error, result.error
  end
  test 'includes request details for read timeout' do
    client = RedminePluginCheck::AiClient.new(ai_settings)
    client.define_singleton_method(:post_json) do |_uri, _body|
      raise Net::ReadTimeout
    end

    result = client.call('plugin report')

    assert !result.success
    assert_equal :request_timeout, result.error
    assert_equal :read_timeout, result.details[:timeout_type]
    assert_equal 'gpt-test', result.details[:model]
    assert_equal 'OpenAI', result.details[:provider]
    assert_equal 13, result.details[:prompt_characters]
    assert result.details[:elapsed_seconds] >= 0
  end
  test 'posts gemini payload and returns candidate text' do
    payloads = []
    client = RedminePluginCheck::AiClient.new(ai_settings('ai_provider_preset' => 'gemini'))
    client.define_singleton_method(:post_json) do |_uri, body|
      payloads << JSON.parse(body)
      FakeResponse.new('200', JSON.generate('candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'Gemini plan' }] } }]))
    end

    result = client.call('plugin report')

    assert result.success
    assert_equal 'Gemini plan', result.content
    assert_equal 'user', payloads.first['contents'].first['role']
    assert_equal 12000, payloads.first['generationConfig']['maxOutputTokens']
  end

  test 'posts claude payload and returns content text' do
    payloads = []
    client = RedminePluginCheck::AiClient.new(ai_settings('ai_provider_preset' => 'claude'))
    client.define_singleton_method(:post_json) do |_uri, body|
      payloads << JSON.parse(body)
      FakeResponse.new('200', JSON.generate('content' => [{ 'type' => 'text', 'text' => 'Claude plan' }]))
    end

    result = client.call('plugin report')

    assert result.success
    assert_equal 'Claude plan', result.content
    assert_equal 'gpt-test', payloads.first['model']
    assert_equal 'System prompt', payloads.first['system']
    assert_equal 12000, payloads.first['max_tokens']
  end

  test 'test connection ignores disabled setting' do
    client = RedminePluginCheck::AiClient.new(ai_settings('ai_enabled' => '0'))
    client.define_singleton_method(:post_json) do |_uri, _body|
      FakeResponse.new('200', JSON.generate('choices' => [{ 'message' => { 'content' => 'OK' } }]))
    end

    result = client.test_connection

    assert result.success
  end
  test 'fetches gemini models that support generate content' do
    client = RedminePluginCheck::AiClient.new(ai_settings('ai_provider_preset' => 'gemini'))
    client.define_singleton_method(:get_json) do |_uri|
      FakeResponse.new('200', JSON.generate('models' => [
        { 'name' => 'models/gemini-1.5-flash', 'supportedGenerationMethods' => ['generateContent'] },
        { 'name' => 'models/embedding-001', 'supportedGenerationMethods' => ['embedContent'] }
      ]))
    end

    result = client.available_models

    assert result.success
    assert_equal ['gemini-1.5-flash'], result.content
  end
test 'fetches openai models' do
  requested_uris = []
  client = RedminePluginCheck::AiClient.new(ai_settings('ai_provider_preset' => 'openai', 'ai_endpoint' => 'https://api.openai.com/v1/chat/completions'))
  client.define_singleton_method(:get_json) do |uri|
    requested_uris << uri.to_s
    FakeResponse.new('200', JSON.generate('data' => [
      { 'id' => 'gpt-4.1-mini' },
      { 'id' => 'gpt-4o-mini' }
    ]))
  end

  result = client.available_models

  assert result.success
  assert_equal 'https://api.openai.com/v1/models', requested_uris.first
  assert_equal ['gpt-4.1-mini', 'gpt-4o-mini'], result.content
end

test 'fetches claude models' do
  requested_uris = []
  client = RedminePluginCheck::AiClient.new(ai_settings('ai_provider_preset' => 'claude'))
  client.define_singleton_method(:get_json) do |uri|
    requested_uris << uri.to_s
    FakeResponse.new('200', JSON.generate('data' => [
      { 'id' => 'claude-3-5-haiku-latest' },
      { 'id' => 'claude-sonnet-4-20250514' }
    ]))
  end

  result = client.available_models

  assert result.success
  assert_equal 'https://api.anthropic.com/v1/models', requested_uris.first
  assert_equal ['claude-3-5-haiku-latest', 'claude-sonnet-4-20250514'], result.content
end

test 'appends chat completions path for v1 endpoint' do
  requested_uris = []
  client = RedminePluginCheck::AiClient.new(ai_settings('ai_provider_preset' => 'azure_openai', 'ai_endpoint' => 'https://example.openai.azure.com/openai/v1'))
  client.define_singleton_method(:post_json) do |uri, _body|
    requested_uris << uri.to_s
    FakeResponse.new('200', JSON.generate('choices' => [{ 'message' => { 'content' => 'OK' } }]))
  end

  result = client.call('plugin report')

  assert result.success
  assert_equal 'https://example.openai.azure.com/openai/v1/chat/completions', requested_uris.first
end

  test 'retries temporary http errors before returning success' do
    responses = [
      FakeResponse.new('503', '{}'),
      FakeResponse.new('200', JSON.generate('choices' => [{ 'message' => { 'content' => 'Retried plan' } }]))
    ]
    client = RedminePluginCheck::AiClient.new(ai_settings)
    client.define_singleton_method(:sleep) { |_seconds| nil }
    client.define_singleton_method(:post_json) do |_uri, _body|
      responses.shift
    end

    result = client.call('plugin report')

    assert result.success
    assert_equal 'Retried plan', result.content
    assert_equal 0, responses.length
  end

  test 'classifies repeated service unavailable after retries' do
    client = RedminePluginCheck::AiClient.new(ai_settings)
    client.define_singleton_method(:sleep) { |_seconds| nil }
    client.define_singleton_method(:post_json) do |_uri, _body|
      FakeResponse.new('503', '{}')
    end

    result = client.call('plugin report')

    assert !result.success
    assert_equal :service_unavailable, result.error
    assert_equal 503, result.status_code
  end
  private

  def ai_settings(overrides = {})
    settings = {
      'ai_enabled' => '1',
      'ai_provider_preset' => 'openai',
      'ai_endpoint' => 'https://example.test/v1/chat/completions',
      'ai_api_key' => 'test-key',
      'ai_api_key_env' => '',
      'ai_model' => 'gpt-test',
      'ai_timeout_seconds' => '5',
      'ai_max_prompt_characters' => '15000',
      'ai_system_prompt' => 'System prompt'
    }
    overrides.each { |key, value| settings[key] = value }
    RedminePluginCheck::AiSettings.new(settings, {})
  end
end
