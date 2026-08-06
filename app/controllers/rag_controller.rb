# Vocabulary for retrieval-augmented lookups. Both lists are narrowed deliberately:
#
#   - Interests are member-submitted free text. Unmoderated suggestions are not vocabulary
#     yet and must not leave the application.
#   - Training topics are the vehicle privileges are conferred through, so the full list is
#     a partial map of who can do what. Only the topics already offered to members go out.
class RagController < AuthenticatedController
  def index
    render json: {
      interests: Interest.approved.alphabetical.pluck(:name),
      training_topics: TrainingTopic.offered_for_members.order(:name).pluck(:name)
    }
  end
end
