# app/services/prow_search_service.rb
class ProwSearchService
  # Searches for Prow records using ransack, optionally restricted by a specific proforma_id.
  def self.search(query_params:, proforma_id: nil)
    qp = query_params.with_indifferent_access

    if proforma_id.present?
      @q = Prow.where('proforma_id = ? and closed is false', proforma_id).ransack(qp)
    else
      profs = Proforma.where('closed is not true').order('created_at desc').select(:id).map(&:id).compact
      @q = Prow.where('proforma_id in (?) and closed is false', profs).ransack(qp)
    end

    Pagy.paginate_by(@q.result(distinct: true), qp[:page] || 1, qp[:per_page] || 25)
  end
end