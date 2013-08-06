class SimpleUploader < Saviour::BaseUploader
  def store_dir
    "/default/path"
  end

  process do
    run :digest_filename
    run :resize, width: 50, height: 50

    run do |contents, filename|
      [contents, "cuca-#{filename}"]
    end

    run :filter
  end

  def resize(contents, filename, opts)
    # Save contents into a localfile
    # run imagemagick to reprocess based on opts[:width] and opts[:height]
    # Read modified file contents and return
    [contents, filename]
  end

  def filter(contents, filename, _)
    # processing...
    [contents, filename]
  end
end