require 'spec_helper'

describe Saviour do
  it "raises error if included in a non active record class" do
    expect {
      Class.new do
        include Saviour::Model
      end
    }.to raise_error(Saviour::NoActiveRecordDetected)
  end

  describe ".attached_files" do
    it "includes a mapping of the currently attached files" do
      uploader = Class.new(Saviour::BaseUploader) do
        store_dir { "/store/dir" }
      end

      klass = Class.new(Test) do
        include Saviour::Model
        attach_file :file, uploader
      end

      expect(klass.attached_files).to eq([:file])
    end
  end

  it "doens't mess with default File constant" do
    # Constant lookup in ruby works by lexical scope, so we can't create classes dynamically like above.
    expect(TestForSaviourFileResolution.new.foo).to be_falsey
  end

  it "shares model definitions with subclasses" do
    uploader = Class.new(Saviour::BaseUploader) do
      store_dir { "/store/dir" }
    end

    klass = Class.new(Test) do
      include Saviour::Model
      attach_file :file, uploader
    end
    expect(klass.attached_files).to eq([:file])

    klass2 = Class.new(klass)
    expect(klass2.attached_files).to eq([:file])

    expect(klass2.new.file).to respond_to :exists?
  end
end
