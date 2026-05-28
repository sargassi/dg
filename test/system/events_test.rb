require "application_system_test_case"

class DirectoryEventsTest < ApplicationSystemTestCase
  setup do
    @event = events(:one)
  end

  test "visiting the index" do
    visit directory_events_url
    assert_selector "h1", text: "Events"
  end

  test "should create event" do
    visit directory_events_url
    click_on "New event"

    fill_in "End time", with: @event.end_time
    fill_in "Eventype", with: @event.eventype_id
    fill_in "Name", with: @event.name
    fill_in "Start time", with: @event.start_time
    click_on "Create Event"

    assert_text "Event was successfully created"
    click_on "Back"
  end

  test "should update Event" do
    visit directory_event_url(@event)
    click_on "Edit this event", match: :first

    fill_in "End time", with: @event.end_time
    fill_in "Eventype", with: @event.eventype_id
    fill_in "Name", with: @event.name
    fill_in "Start time", with: @event.start_time
    click_on "Update Event"

    assert_text "Event was successfully updated"
    click_on "Back"
  end

  test "should destroy Event" do
    visit directory_event_url(@event)
    click_on "Destroy this event", match: :first

    assert_text "Event was successfully destroyed"
  end
end
