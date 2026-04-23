module API
  module V1
    class Prows < Grape::API
      include API::V1::Defaults
      resource :prows do
        desc "Return all prows"
        get "" do
          Prow.all
        end
      desc "Return a prow"
        params do
          requires :id, type: String, desc: "ID of the prow"
        end
        get ":id" do
          Prow.where(id: permitted_params[:id]).first!
        end
      end
    end
  end
end
