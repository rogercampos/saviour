require 'spec_helper'

describe Saviour do
  it "raises error if included in a non active record class" do
    expect {
      Class.new do
        include Saviour::Model
      end
    }.to raise_error(Saviour::NoActiveRecordDetected)
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

  it "subclasses can have independent attachments" do
    uploader = Class.new(Saviour::BaseUploader) do
      store_dir { "/store/dir" }
    end

    klass = Class.new(Test) do
      include Saviour::Model
    end
    expect(klass.attached_files).to eq([])

    klass2 = Class.new(klass) do
      attach_file :file, uploader
    end

    klass3 = Class.new(klass) do
      attach_file :file_thumb, uploader
    end

    expect(klass2.attached_files).to eq([:file])
    expect(klass.attached_files).to eq([])
    expect(klass3.attached_files).to eq([:file_thumb])
  end

  it "subclasses can have independent attachments with followers" do
    uploader = Class.new(Saviour::BaseUploader) do
      store_dir { "/store/dir" }
    end

    klass = Class.new(Test) do
      include Saviour::Model
    end

    klass2 = Class.new(klass) do
      attach_file :file, uploader
      attach_file :file_thumb, uploader, follow: :file, dependent: :destroy
    end

    klass3 = Class.new(klass) do
      attach_file :file_thumb_2, uploader
      attach_file :file_thumb_3, uploader, follow: :file_thumb_2, dependent: :destroy
    end

    expect(klass2.attached_files).to eq([:file, :file_thumb])
    expect(klass2.attached_followers_per_leader).to eq({file: [:file_thumb]})

    expect(klass3.attached_files).to eq([:file_thumb_2, :file_thumb_3])
    expect(klass3.attached_followers_per_leader).to eq({file_thumb_2: [:file_thumb_3]})
  end

  it "subclasses can have independent validations" do
    uploader = Class.new(Saviour::BaseUploader) do
      store_dir { "/store/dir" }
    end

    klass = Class.new(Test) do
      include Saviour::Model
    end

    klass2 = Class.new(klass) do
      attach_file :file, uploader
      attach_validation :file do |contents, filename|
        # pass
      end
    end

    klass3 = Class.new(klass) do
      attach_file :file_thumb_2, uploader
      attach_validation :file_thumb_2 do |contents, filename|
        # pass
      end
    end

    expect(klass2.__saviour_validations.size).to eq 1
    expect(klass2.__saviour_validations.keys).to eq [:file]

    expect(klass3.__saviour_validations.size).to eq 1
    expect(klass3.__saviour_validations.keys).to eq [:file_thumb_2]
  end
end
