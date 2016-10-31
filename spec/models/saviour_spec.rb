require 'spec_helper'

describe Saviour do
  it "raises error if included in a non active record class" do
    expect {
      Class.new do
        include Saviour::Model
      end
    }.to raise_error(Saviour::NoActiveRecordDetected)
  end

  it "error if column not present" do
    expect {
      Class.new(Test) do
        include Saviour::Model

        attach_file :not_present, Saviour::BaseUploader
      end
    }.to raise_error(RuntimeError)
  end

  context do
    it "error if column not present on version" do
      uploader = Class.new(Saviour::BaseUploader) do
        store_dir { "/store/dir" }

        version(:thumb) do
          store_dir { "/versions/store/dir" }
        end

        version(:not_present)
      end

      expect {
        Class.new(Test) do
          include Saviour::Model

          attach_file :file, uploader
        end
      }.to raise_error(RuntimeError)
    end
  end

  it "does not raise error if table is not present" do
    allow(Test).to receive(:table_exists?).and_return(false)

    expect {
      Class.new(Test) do
        include Saviour::Model

        attach_file :not_present, Saviour::BaseUploader
      end
    }.to_not raise_error
  end

  describe ".attached_files" do
    it "includes a mapping of the currently attached files and their versions" do
      uploader = Class.new(Saviour::BaseUploader) do
        store_dir { "/store/dir" }

        version(:thumb)
        version(:thumb_2)
      end

      klass = Class.new(Test) do
        include Saviour::Model
        attach_file :file, uploader
      end

      expect(klass.attached_files).to eq({file: [:thumb, :thumb_2]})

      klass2 = Class.new(Test) do
        include Saviour::Model
        attach_file :file, Saviour::BaseUploader
      end

      expect(klass2.attached_files).to eq({file: []})
    end
  end

  it "doens't mess with default File constant" do
    # Constant lookup in ruby works by lexical scope, so we can't create classes dynamically like above.
    expect(TestForSaviourFileResolution.new.foo).to be_falsey
  end
end
