class ApplicationFormQuestionsController < AdminController
  before_action :set_page
  before_action :set_question, only: %i[edit update destroy]

  def new
    @question = @page.questions.build(
      position: (@page.questions.maximum(:position) || 0) + 1
    )
  end

  def edit; end

  def create
    @question = @page.questions.build(question_params)
    if @question.save
      redirect_to application_form_pages_path, notice: 'Question added.'
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @question.update(question_params)
      redirect_to application_form_pages_path, notice: 'Question updated.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @question.destroy!
    redirect_to application_form_pages_path, notice: 'Question removed.'
  end

  private

  def set_page
    @page = ApplicationFormPage.find(params[:application_form_page_id])
  end

  def set_question
    @question = @page.questions.find(params[:id])
  end

  def question_params
    permitted = params.expect(
      application_form_question: %i[label field_type required position help_text options_text]
    )
    if permitted[:options_text].present?
      permitted[:options_json] = permitted.delete(:options_text)
                                          .split("\n")
                                          .map(&:strip)
                                          .compact_blank
                                          .to_json
    else
      permitted.delete(:options_text)
    end
    permitted
  end
end
