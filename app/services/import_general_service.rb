class ImportGeneralService
  def parse(file, metadata = {})
    ImportParser.new.parse(file, metadata)
  end

  def find_header_row(spreadsheet)
    ImportParser.new.find_header_row(spreadsheet)
  end

  def normalize_header(header)
    ImportParser.new.normalize_header(header)
  end

  def resolve_collection(row, override_collection_id: nil)
    ImportParser.new.resolve_collection(row, override_collection_id: override_collection_id)
  end

  def resolve_warehouse(row)
    ImportParser.new.resolve_warehouse(row)
  end

  def ensure_dependencies!(data)
    ImportPersister.new.ensure_dependencies!(data)
  end

  def classify_rows(data)
    ImportValidator.new.classify_rows(data)
  end

  def validation_details(data)
    ImportValidator.new.validation_details(data)
  end

  def validate_rows(data)
    ImportValidator.new.validate_rows(data)
  end

  def summarize(data)
    ImportValidator.new.summarize(data)
  end

  def save(data, &block)
    ImportPersister.new.save(data, &block)
  end

  def rollback(stats)
    ImportPersister.new.rollback(stats)
  end
end
