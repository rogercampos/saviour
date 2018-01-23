require 'spec_helper'

describe "Introspection of attached files" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  let(:uploader) {
    Class.new(Saviour::BaseUploader) do
      store_dir { "/store/dir" }
    end
  }

  let(:uploader_for_version) {
    Class.new(Saviour::BaseUploader) do
      store_dir { "/store/dir" }

      process do |contents, filename|
        [contents, "new_#{filename}"]
      end
    end
  }

  let(:klass) {
    a = Class.new(Test) { include Saviour::Model }
    a.attach_file :file, uploader
    a.attach_file :file_thumb, uploader_for_version, follow: :file
    a
  }

  describe "Model.attached_files" do
    it "includes a mapping of the currently attached files" do
      expect(klass.attached_files).to eq([:file, :file_thumb])
    end
  end

  describe "Model.attached_followers_per_leader" do
    it "is a hash of attachments and followers" do
      expect(klass.attached_followers_per_leader).to eq({ file: [:file_thumb] })
    end
  end
end