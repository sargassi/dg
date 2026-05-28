require "test_helper"

class Directory::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = events(:one)
  end

  test "should get index" do
    get directory_events_url
    assert_response :success
  end

  test "should get new" do
    get new_directory_event_url
    assert_response :success
  end

  test "should create event" do
    assert_difference("Event.count") do
      post directory_events_url, params: { event: { end_time: @event.end_time, eventype_id: @event.eventype_id, name: @event.name, start_time: @event.start_time } }
    end

    assert_redirected_to directory_event_url(Event.last)
  end

  test "should show event" do
    get directory_event_url(@event)
    assert_response :success
  end

  test "should get edit" do
    get edit_directory_event_url(@event)
    assert_response :success
  end

  test "should update event" do
    patch directory_event_url(@event), params: { event: { end_time: @event.end_time, eventype_id: @event.eventype_id, name: @event.name, start_time: @event.start_time } }
    assert_redirected_to directory_event_url(@event)
  end

  test "should destroy event" do
    assert_difference("Event.count", -1) do
      delete directory_event_url(@event)
    end

    assert_redirected_to directory_events_url
  end
end
