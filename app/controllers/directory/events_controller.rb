class Directory::EventsController < ApplicationController
  include Pagy::Backend
  before_action -> { require_ability!('manage_events_calendar') }
  before_action :set_event, only: %i[ show edit update destroy toggle_enabled ]

  def index
    @date = safe_date(:start_date)
    @todate = safe_date(:selected_date, @date)
    month_start = @date.beginning_of_month
    month_end = @date.end_of_month
    year = @date.year

    non_yearly = Event.recurrents.except(:yearly).values + [nil]
    base = Event.enabled.where(recurrent: non_yearly)
    @events = base.where(start_time: month_start..month_end)
                  .or(base.where(end_time: month_start..month_end))
                  .or(base.where("start_time < ? AND end_time > ?", month_start, month_end))
                  .includes(:eventype)
                  .to_a

    Event.enabled.where(recurrent: :yearly).includes(:eventype).find_each do |event|
      projected_start = Date.new(year, event.start_time.month, event.start_time.day)
      projected_end = event.end_time ? Date.new(year, event.end_time.month, event.end_time.day) : projected_start
      projected_end = projected_end.next_year if projected_end < projected_start

      if projected_start <= month_end && projected_end >= month_start
        event.start_time = projected_start
        event.end_time = projected_end
        @events << event
      end
    end

    @day_events = @events.select { |e| (e.start_time..e.end_time).cover?(@todate) }
    @end_of_week = @todate.end_of_week(:sunday)
    @week_events = @events.select { |e| e.start_time <= @end_of_week && e.end_time >= @todate + 1 }
  end

  def search
    @eventypes = Eventype.all
    @events = Event.includes(:eventype, :user)

    if params[:eventype_id].present?
      @events = @events.where(eventype_id: params[:eventype_id])
    end

    if params[:q].present?
      q = "%#{params[:q]}%"
      @events = @events.where(
        "events.name LIKE :q OR events.description LIKE :q",
        q: q
      )
    end

    if params[:date_from].present?
      @events = @events.where("events.start_time >= ? OR events.end_time >= ?", params[:date_from], params[:date_from])
    end

    if params[:date_to].present?
      @events = @events.where("events.start_time <= ? OR events.end_time <= ?", params[:date_to], params[:date_to])
    end

    if params[:enabled].present?
      @events = @events.where(enabled: true)
    end

    @pagy, @events = pagy(@events.order(created_at: :desc))
  end

  def show
  end

  def new
    @event = Event.new
    @event.start_time = safe_date(:start_date, nil)
    @event.end_time = safe_date(:start_date, nil)
    @event.eventype_id = params[:eventype_id] if params[:eventype_id].present?
  end

  def edit
  end

  def create
    @event = Event.new(event_params)

    if @event.save
      redirect_to directory_events_path(start_date: @event.start_time, selected_date: params[:selected_date]), notice: "Event created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @event.update(event_params)
      redirect_to directory_events_path(start_date: @event.start_time, selected_date: params[:selected_date]), notice: "Event updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy
    redirect_to directory_events_url, notice: "Event deleted."
  end

  def toggle_enabled
    @event.update(enabled: !@event.enabled)
    redirect_back fallback_location: directory_events_path,
                  notice: @event.enabled? ? "Evento abilitato." : "Evento disabilitato."
  end

  private
    def set_event
      @event = Event.find(params[:id])
    end

    def event_params
      params.require(:event).permit(:name, :description, :start_time, :end_time, :eventype_id, :recurrent)
    end

    def safe_date(param_key, default = Date.today)
      raw = params[param_key]
      return default unless raw.present?
      Date.parse(raw.to_s)
    rescue ArgumentError, TypeError
      default
    end
end
