ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  fixtures :users, :collections, :items, :warehouses, :locations, :operationtypes, :inventories, :itemins, :itemouts

  # Add more helper methods to be used by all tests here...
end
