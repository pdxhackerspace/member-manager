require 'test_helper'

class AccessControllerTrainingSyncJobTest < ActiveJob::TestCase
  setup do
    @laser_topic = training_topics(:laser_cutting)
    @laser_type = access_controller_types(:laser_controller)
    @door_type = access_controller_types(:door_lock)

    # laser_controller type requires laser_cutting (see fixtures).
    @laser_one = AccessController.create!(name: 'Laser 1', hostname: 'laser1.local',
                                          access_controller_type: @laser_type)
    @laser_two = AccessController.create!(name: 'Laser 2', hostname: 'laser2.local',
                                          access_controller_type: @laser_type)
    @laser_disabled = AccessController.create!(name: 'Laser 3', hostname: 'laser3.local',
                                               access_controller_type: @laser_type, enabled: false)
    @door = AccessController.create!(name: 'Door 1', hostname: 'door1.local', access_controller_type: @door_type)
  end

  test 'syncs only enabled controllers of types requiring the topic' do
    assert_enqueued_jobs 2, only: AccessControllerVerbJob do
      AccessControllerTrainingSyncJob.perform_now(@laser_topic.id)
    end

    assert_enqueued_with(job: AccessControllerVerbJob, args: [@laser_one.id, 'sync'])
    assert_enqueued_with(job: AccessControllerVerbJob, args: [@laser_two.id, 'sync'])
  end

  test 'does nothing when no controller type requires the topic' do
    woodworking = training_topics(:woodworking)

    assert_no_enqueued_jobs only: AccessControllerVerbJob do
      AccessControllerTrainingSyncJob.perform_now(woodworking.id)
    end
  end

  test 'skips controllers whose type is disabled' do
    AccessControllerTypeTrainingTopic.create!(
      access_controller_type: access_controller_types(:disabled_type),
      training_topic: @laser_topic
    )
    AccessController.create!(name: 'Disabled C', hostname: 'd.local',
                             access_controller_type: access_controller_types(:disabled_type))

    # Still only the two enabled laser controllers, not the disabled-type controller.
    assert_enqueued_jobs 2, only: AccessControllerVerbJob do
      AccessControllerTrainingSyncJob.perform_now(@laser_topic.id)
    end
  end
end
