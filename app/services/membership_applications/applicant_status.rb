module MembershipApplications
  class ApplicantStatus
    STAGES = {
      submitted: 1,
      review_begun: 2,
      complete: 3
    }.freeze

    STEP_LABELS = [
      { key: :submitted, label: 'Application submitted', step: '1/3' },
      { key: :review_begun, label: 'Review process begun', step: '2/3' },
      { key: :complete, label: 'Application process complete', step: '3/3' }
    ].freeze

    def self.for(application)
      new(application)
    end

    def initialize(application)
      @application = application
    end

    def stage
      return :complete if @application.approved? || @application.rejected?
      return :review_begun if review_process_begun?

      :submitted
    end

    def step_number
      STAGES.fetch(stage)
    end

    def progress_percent
      (step_number / 3.0 * 100).round
    end

    def complete?
      stage == :complete
    end

    def headline
      case stage
      when :submitted
        'Your application is in the queue for review.'
      when :review_begun
        'Your application is being reviewed.'
      when :complete
        if @application.approved?
          'Your application has been approved.'
        else
          'Your application has been reviewed.'
        end
      end
    end

    def step_labels
      STEP_LABELS
    end

    def step_active?(step_key)
      STAGES.fetch(step_key) <= step_number
    end

    def step_current?(step_key)
      stage == step_key
    end

    private

    def review_process_begun?
      @application.in_review? ||
        @application.acceptance_votes.exists? ||
        @application.tour_feedbacks.exists?
    end
  end
end
