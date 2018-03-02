require 'spec_helper'

describe "stash data on process" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  it 'stores data on after upload on update' do
    uploader = Class.new(Saviour::BaseUploader) {
      store_dir { "/store/dir" }

      process_with_file do |file, filename|
        stash(file_size: File.size(file.path))

        [file, filename]
      end

      after_upload do |stash|
        model.update_attributes!(file_size: stash[:file_size])
      end
    }

    klass = Class.new(Test) { include Saviour::Model }
    klass.attach_file :file, uploader

    a = klass.create!

    a.update_attributes! file: Saviour::StringSource.new("a" * 74, "file.txt")
    expect(a.file_size).to eq 74
  end

  it 'stores data on after upload on create' do
    uploader = Class.new(Saviour::BaseUploader) {
      store_dir { "/store/dir" }

      process_with_file do |file, filename|
        stash(file_size: File.size(file.path))

        [file, filename]
      end

      after_upload do |stash|
        model.update_attributes!(file_size: stash[:file_size])
      end
    }

    klass = Class.new(Test) { include Saviour::Model }
    klass.attach_file :file, uploader

    a = klass.create! file: Saviour::StringSource.new("a" * 74, "file.txt")

    expect(a.file_size).to eq 74
  end

  it 'stashes are independent per uploader' do
    uploader = Class.new(Saviour::BaseUploader) {
      store_dir { "/store/dir" }

      process_with_file do |file, filename|
        # same ':size' key in the stash
        stash(size: File.size(file.path))

        [file, filename]
      end

      after_upload do |stash|
        model.update_attributes!("size_#{attached_as}" => stash[:size])
      end
    }

    klass = Class.new(Test) { include Saviour::Model }
    klass.attach_file :file, uploader
    klass.attach_file :file_thumb, uploader

    a = klass.create!

    # - 1 initial empty query
    # - 2 queries to update size
    # - 1 query to assign stored paths
    expect_to_yield_queries(count: 4) do
      a.update_attributes! file: Saviour::StringSource.new("a" * 74, "file.txt"),
                           file_thumb: Saviour::StringSource.new("a" * 31, "file_2.txt")
    end

    expect(a.size_file).to eq 74
    expect(a.size_file_thumb).to eq 31
  end
end