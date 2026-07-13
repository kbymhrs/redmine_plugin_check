require File.expand_path('../../test_helper', File.dirname(__FILE__))

require_relative '../../../app/services/redmine_plugin_check/ai_settings' unless defined?(RedminePluginCheck::AiSettings)
require_relative '../../../app/controllers/redmine_plugin_check_controller' unless defined?(RedminePluginCheckController)

class RedminePluginCheckControllerFilenameTest < ActiveSupport::TestCase
  test 'uses provider model and local minute timestamp for ai analysis filename' do
    controller = RedminePluginCheckController.new
    params = ActionController::Parameters.new(
      :provider => 'OpenAI',
      :model => 'gpt-5.4-mini',
      :generated_at => '2026-07-13 18:58:36 +0900'
    )
    controller.params = params

    assert_equal 'plugin_check_openai-gpt-5.4-mini_202607131858.md', controller.send(:ai_analysis_filename)
  end

  test 'sanitizes provider and model for ai analysis filename' do
    controller = RedminePluginCheckController.new
    controller.params = ActionController::Parameters.new(
      :provider => 'Azure OpenAI',
      :model => 'deployments/my model',
      :generated_at => '2026-07-13 09:58:36 +0000'
    )

    assert_equal 'plugin_check_azure-openai-deployments-my-model_202607130958.md', controller.send(:ai_analysis_filename)
  end
end

