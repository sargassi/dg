json.extract! event, :id, :name, :start_time, :end_time, :eventype_id, :created_at, :updated_at
json.url event_url(event, format: :json)
