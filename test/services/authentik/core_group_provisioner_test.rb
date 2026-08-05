require 'test_helper'

module Authentik
  class CoreGroupProvisionerTest < ActiveSupport::TestCase
    NEW_NAME = Authentik::CoreGroupProvisioner::SYSTEM_APP_NAME
    LEGACY_NAME = Authentik::CoreGroupProvisioner::LEGACY_SYSTEM_APP_NAME

    setup do
      Application.where(name: [NEW_NAME, LEGACY_NAME]).destroy_all
    end

    test 'creates the system application when neither name is present' do
      app = nil

      assert_difference -> { Application.where(name: NEW_NAME).count }, 1 do
        app = Authentik::CoreGroupProvisioner.system_application
      end

      assert_equal NEW_NAME, app.name
    end

    test 'reuses the system application once it carries the new name' do
      existing = Application.create!(name: NEW_NAME)

      assert_no_difference -> { Application.count } do
        assert_equal existing, Authentik::CoreGroupProvisioner.system_application
      end
    end

    # The rename must not fork the application: a second row would take every core and
    # training group with it and orphan the ones already wired up to Authentik.
    test 'adopts and renames a pre-rename application instead of creating a second one' do
      legacy = Application.create!(name: LEGACY_NAME)
      group = legacy.application_groups.create!(
        name: 'Active Members',
        authentik_name: 'active-members',
        member_source: 'active_members'
      )

      assert_no_difference -> { Application.count } do
        assert_equal legacy, Authentik::CoreGroupProvisioner.system_application
      end

      assert_equal NEW_NAME, legacy.reload.name
      assert_equal legacy, group.reload.application
    end

    # applications.name is not uniquely indexed, so renaming the legacy row here would
    # leave two applications answering to the new name.
    test 'leaves a pre-rename application alone when the new name is already taken' do
      current = Application.create!(name: NEW_NAME)
      legacy = Application.create!(name: LEGACY_NAME)

      assert_equal current, Authentik::CoreGroupProvisioner.system_application
      assert_equal LEGACY_NAME, legacy.reload.name
    end

    test 'provisioning a topic reuses the pre-rename application' do
      legacy = Application.create!(name: LEGACY_NAME)

      assert_no_difference -> { Application.count } do
        TrainingTopic.create!(name: "Lathe #{SecureRandom.hex(4)}")
      end

      assert_equal NEW_NAME, legacy.reload.name
    end
  end
end
