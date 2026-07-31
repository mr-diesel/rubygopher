module Interview
  module API
    class Questions < Grape::API
      helpers Identity::API::AuthHelpers

      helpers do
        def serialize(question, positions)
          {
            id: question.id,
            label: question.label,
            question: question.question,
            answer: question.answer,
            code: question.code,
            language: question.language,
            category: question.category,
            position: positions[question.id] || question.position,
            default: question.default?,
            editable: question.user_id == current_user.id
          }
        end

        def attrs
          declared(params, include_missing: false).to_h.symbolize_keys
        end
      end

      before { authenticate! }

      resource :interview_questions do
        get do
          questions = InterviewQuestion.visible_to(current_user)
          positions = current_user.user_question_orders.pluck(:interview_question_id, :position).to_h
          questions.map { |q| serialize(q, positions) }
        end

        params do
          requires :ordered_ids, type: Array[Integer]
        end
        patch :reorder do
          current_user.reorder_questions!(params[:ordered_ids])
          status 204
        end

        params do
          requires :label, type: String
          requires :question, type: String
          optional :answer, type: String
          optional :code, type: String
          optional :language, type: String
          optional :category, type: String
        end
        post do
          question = current_user.interview_questions.create!(attrs)
          status 201
          serialize(question, {})
        end

        route_param :id, type: Integer do
          params do
            optional :label, type: String
            optional :question, type: String
            optional :answer, type: String
            optional :code, type: String
            optional :language, type: String
            optional :category, type: String
          end
          patch do
            question = current_user.interview_questions.find(params[:id])
            question.update!(attrs.except(:id))
            positions = current_user.user_question_orders.pluck(:interview_question_id, :position).to_h
            serialize(question, positions)
          end

          delete do
            current_user.interview_questions.find(params[:id]).destroy!
            status 204
          end

          post :hide do
            question = InterviewQuestion.defaults.find(params[:id])
            current_user.hidden_interview_questions.find_or_create_by!(interview_question: question)
            status 204
          end

          delete :hide do
            current_user.hidden_interview_questions.where(interview_question_id: params[:id]).destroy_all
            status 204
          end
        end
      end

      resource :interview_categories do
        get do
          categories = InterviewQuestion.visible_to(current_user).reorder(nil).distinct.pluck(:category)
          orders = current_user.user_category_orders.pluck(:category, :position).to_h
          categories.sort_by { |c| [orders[c] || Float::INFINITY, c] }
        end

        params do
          requires :ordered, type: Array[String]
        end
        patch :reorder do
          current_user.reorder_categories!(params[:ordered])
          status 204
        end
      end
    end
  end
end
