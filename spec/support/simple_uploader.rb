class SimpleUploader < Saviour::BaseUploader
  store_dir! { "/default/path" }

  run :digest_filename
  run :resize, width: 50, height: 50

  run_with_file do |local_file, filename|
    # You're passed a File object pointing to a temporal file containing the current contents

    # Modify the passed file
    # `mogrify -resize '40x40' #{local_file.path}`

    # You must return a File object and a filename. We'll use the contents you left on that file.
    # you can return a different file from the one you received, but then it's up to you to remove that temporal file (if it's temporal)
    # We won't cleanup that, since you created it.
    [local_file, filename]
  end

  run do |contents, filename|
    [contents, "cuca-#{filename}"]
  end

  version(:thumb) do
    store_dir! { "/default/path/versions" }
    run :resize, with: 10, height: 10
  end

  version(:copy_without_filter)

  run :filter

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


class Model < ActiveRecord::Base
  include Saviour

  attach_file :file, SimpleUploader, versions: [:thumb, :copy_without_filter]
  attach_validation(:file) do |contents|
    errors.add(:file, "Cannot start with 'A'") if contents.start_with?("A")
  end
  attach_validation :file, :check_filesize


  def check_filesize(contents)
    if contents.length > 5 * 1024 * 1024
      errors.add(:file, "Max filesize allowed is 5Mb")
    end
  end
end


__END__

a = Model.new file: File.open("local/path.jpg")
a.save!

a.file.url
a.file(nil).url
a.file(:thumb).url
a.file("thumb").url
