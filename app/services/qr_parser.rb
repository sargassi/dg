class QrParser
  FORMAT_3PART = /\A(.+)_(\d{4})_(\d+)\z/
  FORMAT_2PART = /\A(.+)_(\d+)\z/

  def self.parse(text)
    if text =~ FORMAT_3PART
      gencode = $1
      collection_id = $2.to_i
      detail_id = $3.to_i
      return { gencode: gencode, collection_id: collection_id, detail_id: detail_id }
    end

    if text =~ FORMAT_2PART
      candidate_gencode = $1
      candidate_detail_id = $2.to_i
      if candidate_gencode =~ /_(\d+)\z/
        return { gencode: candidate_gencode, collection_id: nil, detail_id: candidate_detail_id }
      end
    end

    { gencode: text, collection_id: nil, detail_id: nil }
  end
end
