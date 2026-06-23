require File.expand_path('../../test_helper', File.dirname(__FILE__))

require_relative '../../../app/services/redmine_plugin_check/version_requirement' unless defined?(RedminePluginCheck::VersionRequirement)

class RedminePluginCheckVersionRequirementTest < ActiveSupport::TestCase
  test 'supports version_or_higher hash' do
    requirement = RedminePluginCheck::VersionRequirement.new(:version_or_higher => '5.0.0')

    assert requirement.satisfied_by?('6.0.0')
    assert requirement.satisfied_by?('5.0.0')
    assert_not requirement.satisfied_by?('4.2.0')
    assert requirement.lower_bound_only?
    assert_equal Gem::Version.new('5.0.0'), requirement.minimum_version
  end

  test 'supports exact version hash' do
    requirement = RedminePluginCheck::VersionRequirement.new(:version => '5.1.0')

    assert requirement.satisfied_by?('5.1.0')
    assert_not requirement.satisfied_by?('5.1.1')
    assert_not requirement.lower_bound_only?
  end

  test 'supports operator strings' do
    requirement = RedminePluginCheck::VersionRequirement.new('>= 5.0.0 < 6.0.0')

    assert requirement.satisfied_by?('5.1.0')
    assert_not requirement.satisfied_by?('6.0.0')
    assert_not requirement.lower_bound_only?
  end

  test 'supports ruby hash syntax captured from init rb' do
    requirement = RedminePluginCheck::VersionRequirement.new("version_or_higher: '5.0.0'")

    assert requirement.satisfied_by?('5.0.1')
  end
  test 'treats bare requires_redmine string as version_or_higher' do
    requirement = RedminePluginCheck::VersionRequirement.new('3.0')

    assert requirement.satisfied_by?('3.0.7')
    assert requirement.satisfied_by?('6.1.2')
    assert_not requirement.satisfied_by?('2.6.10')
    assert requirement.lower_bound_only?
  end

  test 'matches redmine partial version semantics for version hash' do
    requirement = RedminePluginCheck::VersionRequirement.new(:version => '3.0')

    assert requirement.satisfied_by?('3.0.7')
    assert_not requirement.satisfied_by?('3.1.0')
    assert_not requirement.satisfied_by?('6.1.2')
  end

  test 'supports redmine version arrays as alternatives' do
    requirement = RedminePluginCheck::VersionRequirement.new(:version => ['3.3.3', '4.2'])

    assert requirement.satisfied_by?('3.3.3')
    assert requirement.satisfied_by?('4.2.11')
    assert_not requirement.satisfied_by?('5.0.0')
  end

  test 'supports redmine version ranges' do
    requirement = RedminePluginCheck::VersionRequirement.new(:version => ('3.3.0'..'6.1'))

    assert requirement.satisfied_by?('3.3.3')
    assert requirement.satisfied_by?('6.1.2')
    assert_not requirement.satisfied_by?('6.2.0')
  end

  test 'supports ruby hash range syntax captured from init rb' do
    requirement = RedminePluginCheck::VersionRequirement.new(":version => '3.3.0'..'6.1'")

    assert requirement.satisfied_by?('6.1.2')
    assert_not requirement.satisfied_by?('6.2.0')
  end
end
