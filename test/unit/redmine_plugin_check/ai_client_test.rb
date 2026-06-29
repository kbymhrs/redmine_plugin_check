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

    result = client.call('x' * 500)
    sent_prompt = payloads.first['messages'].last['content']

    assert result.success
    assert sent_prompt.length <= 160
    assert_includes sent_prompt, 'TRUNCATED'
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

  private

  def ai_settings(overrides = {})
    settings = {
      'ai_enabled' => '1',
      'ai_endpoint' => 'https://example.test/v1/chat/completions',
      'ai_api_key' => 'test-key',
      'ai_api_key_env' => '',
      'ai_model' => 'gpt-test',
      'ai_timeout_seconds' => '5',
      'ai_max_prompt_characters' => '30000',
      'ai_system_prompt' => 'System prompt'
    }
    overrides.each { |key, value| settings[key] = value }
    RedminePluginCheck::AiSettings.new(settings, {})
  end
end