json.extract! proforma, :id, :customer, :data_in, :data_out, :closed, :note, :created_at, :updated_at
json.url proforma_url(proforma, format: :json)
