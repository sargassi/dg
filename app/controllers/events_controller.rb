class EventsController < ApplicationController
  before_action :set_event, only: %i[ show edit update destroy ]

  def index
    @date = safe_date(:start_date)
    @todate = safe_date(:selected_date, @date)
    month_start = @date.beginning_of_month
    month_end = @date.end_of_month

    @events = Event.where(start_time: month_start..month_end)
                   .or(Event.where(end_time: month_start..month_end))
                   .or(Event.where("start_time < ? AND end_time > ?", month_start, month_end))
                   .includes(:eventype)

    @day_events = @events.select { |e| (e.start_time..e.end_time).cover?(@todate) }
    @end_of_week = @todate.end_of_week(:sunday)
    @week_events = @events.select { |e| e.start_time <= @end_of_week && e.end_time >= @todate + 1 }
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
      redirect_to events_path(start_date: @event.start_time, selected_date: params[:selected_date]), notice: "Event created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @event.update(event_params)
      redirect_to events_path(start_date: @event.start_time, selected_date: params[:selected_date]), notice: "Event updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy
    redirect_to events_url, notice: "Event deleted."
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


