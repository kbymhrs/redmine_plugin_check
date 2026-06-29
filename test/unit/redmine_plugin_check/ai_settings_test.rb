require File.expand_path('../../test_helper', File.dirname(__FILE__))

require_relative '../../../app/services/redmine_plugin_check/ai_settings' unless defined?(RedminePluginCheck::AiSettings)

class RedminePluginCheckAiSettingsTest < ActiveSupport::TestCase
  test 'reads api key from environment before saved setting' do
    settings = RedminePluginCheck::AiSettings.new(
      {
        'ai_api_key' => 'saved-key',
        'ai_api_key_env' => 'PLUGIN_CHECK_KEY'
      },
      'PLUGIN_CHECK_KEY' => 'env-key'
    )

    assert_equal 'env-key', settings.api_key
  end

  test 'falls back to saved api key when environment variable is empty' do
    settings = RedminePluginCheck::AiSettings.new(
      {
        'ai_api_key' => 'saved-key',
        'ai_api_key_env' => 'PLUGIN_CHECK_KEY'
      },
      'PLUGIN_CHECK_KEY' => ''
    )

    assert_equal 'saved-key', settings.api_key
  end

  test 'uses positive integer defaults for invalid numeric settings' do
    settings = RedminePluginCheck::AiSettings.new(
      {
        'ai_timeout_seconds' => '0',
        'ai_max_prompt_characters' => 'invalid'
      },
      {}
    )

    assert_equal 60, settings.timeout_seconds
    assert_equal 30000, settings.max_prompt_characters
  end
end