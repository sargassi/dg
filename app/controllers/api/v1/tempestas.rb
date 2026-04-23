module API
  module V1
    class Tempestas < Grape::API
      include API::V1::Defaults
      resource :tempesta do
        desc "get single tempesta"
        params do
          #requires :id, type: String, desc: "tempestid"
          requires :station, type: String, desc: "station of the cross"
          requires :prow_id, type: String, desc: "id riga"
          requires :qrcode, type: String, desc: "qr"
        end

        get "" do
            { 'declared_params' => declared(params) }
            case params[:station]
            when 'F1'
              Tempesta.where('f1 is null and prow_id = ? and qrcode = ?', params[:prow_id], params[:qrcode])
            when 'F2'
              Tempesta.where('f2 is null and prow_id = ? and qrcode = ?', params[:prow_id], params[:qrcode])
            when 'F3'
              Tempesta.where('f3 is null and prow_id = ? and qrcode = ?', params[:prow_id], params[:qrcode])
            when 'F4'
              Tempesta.where('f4 is null and prow_id = ? and qrcode = ?', params[:prow_id], params[:qrcode])
            when 'F5'
              Tempesta.where('f5 is null and prow_id = ? and qrcode = ?', params[:prow_id], params[:qrcode])
            else
            end
        end
      end
    end
  end
end
