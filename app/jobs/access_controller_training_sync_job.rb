class AccessControllerTrainingSyncJob < ApplicationJob
  queue_as :default

  # Re-syncs every enabled access controller whose (enabled) type requires the given
  # training topic. A user's training change can grant or revoke their access on those
  # controllers, so the full authorized-user payload must be pushed again.
  def perform(training_topic_id)
    type_ids = AccessControllerType.enabled
                                   .joins(:access_controller_type_training_topics)
                                   .where(access_controller_type_training_topics: {
                                            training_topic_id: training_topic_id
                                          })
                                   .distinct
                                   .pluck(:id)
    return if type_ids.empty?

    AccessController.enabled
                    .where(access_controller_type_id: type_ids)
                    .find_each do |controller|
      AccessControllerVerbJob.perform_later(controller.id, 'sync')
    end
  end
end
