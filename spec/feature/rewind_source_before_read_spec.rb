require 'spec_helper'

describe 'source is rewinded before read' do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  it do
    uploader = Class.new(Saviour::BaseUploader) {
      store_dir { "/store/dir/#{model.id}" }
    }
    klass = Class.new(Test) { include Saviour::Model }
    klass.attach_file :file, uploader

    with_test_file("example.xml") do |file|
      a = klass.create! file: file
      b = klass.create! file: file

      expect(a.file.read.bytesize).to eq 409
      expect(b.file.read.bytesize).to eq 409
    end
  end
end