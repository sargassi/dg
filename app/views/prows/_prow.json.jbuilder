json.extract! prow, :id, :code, :proforma_id, :description, :note, :qty, :qr, :created_at, :updated_at
json.url prow_url(prow, format: :json)
