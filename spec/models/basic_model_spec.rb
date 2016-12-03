require 'spec_helper'

describe Saviour do
  describe ".attached_files" do
    it "includes a mapping of the currently attached files and their versions" do
      uploader = Class.new(Saviour::BaseUploader) do
        store_dir { "/store/dir" }

        version(:thumb)
        version(:thumb_2)
      end

      klass = Class.new do
        include Saviour::BasicModel
        attach_file :file, uploader
      end

      expect(klass.attached_files).to eq({file: [:thumb, :thumb_2]})

      klass2 = Class.new do
        include Saviour::BasicModel
        attach_file :file, Saviour::BaseUploader
      end

      expect(klass2.attached_files).to eq({file: []})
    end
  end

  it "doens't mess with default File constant" do
    # Constant lookup in ruby works by lexical scope, so we can't create classes dynamically like above.
    expect(TestForSaviourFileResolution.new.foo).to be_falsey
  end

  it "shares model definitions with subclasses" do
    uploader = Class.new(Saviour::BaseUploader) do
      store_dir { "/store/dir" }
      version(:thumb)
    end

    klass = Class.new do
      include Saviour::BasicModel
      attach_file :file, uploader
    end
    expect(klass.attached_files).to eq({file: [:thumb]})

    klass2 = Class.new(klass)
    expect(klass2.attached_files).to eq({file: [:thumb]})

    expect(klass2.new.file).to respond_to :exists?
  end
end
