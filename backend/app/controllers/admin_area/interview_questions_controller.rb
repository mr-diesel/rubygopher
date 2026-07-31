module AdminArea
  class InterviewQuestionsController < ApplicationController
    before_action :set_question, only: %i[edit update destroy]

    def index
      @questions = InterviewQuestion.defaults.ordered
    end

    def new
      @question = InterviewQuestion.new
    end

    def create
      @question = InterviewQuestion.new(question_params)
      if @question.save
        redirect_to admin_interview_questions_path, notice: "Question created"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @question.update(question_params)
        redirect_to admin_interview_questions_path, notice: "Question updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @question.destroy
      redirect_to admin_interview_questions_path, notice: "Question deleted"
    end

    private

    def set_question
      @question = InterviewQuestion.defaults.find(params[:id])
    end

    def question_params
      params.require(:interview_question).permit(:label, :question, :answer, :code, :language, :category, :position)
    end
  end
end
