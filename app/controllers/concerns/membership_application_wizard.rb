# frozen_string_literal: true

# Public multi-step application flow (email verification required).
module MembershipApplicationWizard
  extend ActiveSupport::Concern

  included do
    before_action :require_verified_email!, only: %i[start save_page page submit_application]
    before_action :load_pages, only: %i[start page]
  end

  def start
    @intro_content = TextFragment.content_for('application_form_intro')
    @verification = current_verification
    @email = @verification&.email

    @application = find_in_progress_application
    if @application.nil? && @email
      draft = MembershipApplication.find_by(email: @email, status: 'draft')
      if draft
        session[:application_token] = draft.token
        @application = draft
      end
    end

    return unless @email

    @existing_application = MembershipApplication.where(email: @email)
                                                 .where.not(status: 'draft')
                                                 .newest_first
                                                 .first
  end

  def save_page
    page_number = params[:page_number].to_i

    if page_number.zero?
      save_email_page
    else
      save_question_page(page_number)
    end
  end

  def page
    @application = find_in_progress_application
    unless @application
      redirect_to apply_start_path, alert: 'Please start your application to continue.'
      return
    end

    page_number = params[:page_number].to_i
    @current_page = @pages[page_number - 1]
    unless @current_page
      redirect_to apply_start_path
      return
    end

    @page_number = page_number
    @questions = @current_page.questions.ordered
  end

  def submit_application
    @application = find_in_progress_application
    unless @application&.draft?
      redirect_to apply_start_path, alert: 'No application in progress.'
      return
    end

    missing = check_required_fields
    if missing.any?
      redirect_to apply_page_path(page_number: missing.first[:page_number]),
                  alert: 'Please complete required fields before submitting.'
      return
    end

    @application.submit!
    session.delete(:application_token)
    redirect_to apply_confirmation_path
  end

  def confirmation; end

  private

  def load_pages
    @pages = ApplicationFormPage.ordered.to_a
  end

  def find_in_progress_application
    token = session[:application_token]
    return nil unless token

    MembershipApplication.find_by(token: token, status: 'draft')
  end

  def persist_answers_for_questions!(current_page, answers, answers_other)
    current_page.questions.each do |question|
      value = answers[question.id.to_s].to_s.strip
      if value == 'Other'
        other_value = answers_other[question.id.to_s].to_s.strip
        value = other_value.presence || 'Other'
      end
      answer = @application.application_answers.find_or_initialize_by(
        application_form_question: question
      )
      answer.value = value
      answer.save!
    end
  end

  def redirect_after_saving_page(page_number, page_count)
    next_page = page_number + 1
    if next_page > page_count
      redirect_to apply_page_path(page_number: page_number),
                  notice: 'Answers saved. Review and submit when ready.'
    else
      redirect_to apply_page_path(page_number: next_page)
    end
  end

  def save_email_page
    verification = current_verification
    email = verification.email

    app = MembershipApplication.find_by(email: email, status: 'draft')
    app ||= MembershipApplication.create!(email: email)

    session[:application_token] = app.token
    redirect_to apply_page_path(page_number: 1)
  end

  def save_question_page(page_number)
    @application = find_in_progress_application
    unless @application
      redirect_to apply_start_path, alert: 'Please start your application to continue.'
      return
    end

    pages = ApplicationFormPage.ordered.to_a
    current_page = pages[page_number - 1]
    unless current_page
      redirect_to apply_start_path
      return
    end

    persist_answers_for_questions!(current_page, params[:answers] || {}, params[:answers_other] || {})

    redirect_after_saving_page(page_number, pages.size)
  end

  def check_required_fields
    missing = []
    ApplicationFormPage.ordered.each_with_index do |page, idx|
      page.questions.where(required: true).find_each do |q|
        answer = @application.answer_for(q)
        missing << { page_number: idx + 1, question: q } if answer.nil? || answer.value.blank?
      end
    end
    missing
  end

  def require_verified_email!
    verification = current_verification
    return if verification&.verified?

    redirect_to apply_new_path, alert: 'Please verify your email address before starting an application.'
  end

  def current_verification
    token = session[:verified_application_token]
    return nil unless token

    ApplicationVerification.find_by(token: token)
  end
end
