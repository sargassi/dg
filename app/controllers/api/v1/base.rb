module API
  module V1
    class Base < Grape::API
      mount API::V1::Prows
      mount API::V1::Tempestas
    end
  end
end
