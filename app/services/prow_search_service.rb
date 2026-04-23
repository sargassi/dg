<<~RUBY
# app/services/prow_search_service.rb
class ProwSearchService
  # Searches for Prow records using ransack, optionally restricted by a specific proforma_id.
  def self.search(query_params:, proforma_id: nil)
    params = params.with_indifferent_access

    if proforma_id.present?
      # Searching within a single Proforma
      @q = Prow.where('proforma_id = ? and closed is false', proforma_id).ransack(query_params)
    else
      # Searching across all active Proformas
      profs = Proforma.where('closed is not true').order('created_at desc').select(:id).map(&:id).compact
      @q = Prow.where('proforma_id in (?) and closed is false', profs).ransack(query_params)
    end

    Pagy.paginate_by(@q.result(distinct: true), params[:page] || 1, params[:per_page] || 25)
  end
end
RUBY