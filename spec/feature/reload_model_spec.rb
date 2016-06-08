require 'spec_helper'

describe "reload model" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  context "updates the Saviour::File instance" do
    it do
      uploader = Class.new(Saviour::BaseUploader) { store_dir { "/store/dir" } }
      klass = Class.new(Test) { include Saviour }
      klass.attach_file :file, uploader
      a = klass.create!
      b = klass.find(a.id)

      with_test_file("example.xml") do |example|
        a.update_attributes! file: example
        expect(a.file.exists?).to be_truthy
        expect(b.file.exists?).to be_falsey

        b.reload
        expect(b.file.exists?).to be_truthy
      end
    end
  end
end
