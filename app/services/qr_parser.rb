class QrParser
  def self.parse(text)
    if text =~ /\A(.+)_(\d+)\z/
      candidate_gencode = $1
      candidate_detail_id = $2.to_i
      if candidate_gencode =~ /_(\d+)\z/
        return { gencode: candidate_gencode, detail_id: candidate_detail_id }
      end
    end
    { gencode: text, detail_id: nil }
  end
end
