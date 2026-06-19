require File.expand_path('../../test_helper', File.dirname(__FILE__))

require_relative '../../../app/services/redmine_upgrade_advisor/version_requirement'

class RedmineUpgradeAdvisorVersionRequirementTest < ActiveSupport::TestCase
  test 'supports version_or_higher hash' do
    requirement = RedmineUpgradeAdvisor::VersionRequirement.new(:version_or_higher => '5.0.0')

    assert requirement.satisfied_by?('6.0.0')
    assert requirement.satisfied_by?('5.0.0')
    assert_not requirement.satisfied_by?('4.2.0')
    assert requirement.lower_bound_only?
    assert_equal Gem::Version.new('5.0.0'), requirement.minimum_version
  end

  test 'supports exact version hash' do
    requirement = RedmineUpgradeAdvisor::VersionRequirement.new(:version => '5.1.0')

    assert requirement.satisfied_by?('5.1.0')
    assert_not requirement.satisfied_by?('5.1.1')
    assert_not requirement.lower_bound_only?
  end

  test 'supports operator strings' do
    requirement = RedmineUpgradeAdvisor::VersionRequirement.new('>= 5.0.0 < 6.0.0')

    assert requirement.satisfied_by?('5.1.0')
    assert_not requirement.satisfied_by?('6.0.0')
    assert_not requirement.lower_bound_only?
  end

  test 'supports ruby hash syntax captured from init rb' do
    requirement = RedmineUpgradeAdvisor::VersionRequirement.new("version_or_higher: '5.0.0'")

    assert requirement.satisfied_by?('5.0.1')
  end
end
