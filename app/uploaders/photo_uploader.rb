class PhotoUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  #process resize_to_fit: [800, 800]

  storage :file

  def store_dir
    'public/my/upload/directory'
  end

  version :thumb do
    process :convert_cover => :jpg
    process resize_to_fill: [600,600]
  end


  
  def convert_cover(format)
    manipulate! do |img| # this is ::MiniMagick::Image instance
      img.format(format.to_s.downcase, 0)
      img
    end
  end

end