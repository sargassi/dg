# app/services/dashboard_service.rb
class DashboardService
  # Returns the initial set of sections used on the dashboard.
  def self.get_sections
    ['F1', 'F2', 'F3', 'F4', 'F5']
  end
end