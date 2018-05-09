require 'spec_helper'

describe "reload" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  describe "updates the Saviour::File instances on the model" do
    it do
      uploader = Class.new(Saviour::BaseUploader) { store_dir { "/store/dir" } }
      klass = Class.new(Test) { include Saviour::Model }
      klass.attach_file :file, uploader
      a = klass.create!
      b = klass.find(a.id)

      with_test_file("example.xml") do |example|
        a.update_attributes! file: example
        expect(a.file.exists?).to be_truthy
        expect(b.file.exists?).to be_falsey

        b.reload(lock: false)
        expect(b.file.exists?).to be_truthy
      end
    end
  end

  it "reloads the file instance" do
    uploader = Class.new(Saviour::BaseUploader) { store_dir { "/store/dir" } }
    klass = Class.new(Test) { include Saviour::Model }
    klass.attach_file :file, uploader
    a = klass.create!

    expect(a.file.present?).to be_falsey
    Saviour::Config.storage.write "contents", "file.txt"
    a.update_columns(file: "file.txt")
    expect(a.file.present?).to be_falsey

    a.file.reload
    expect(a.file.present?).to be_truthy
    expect(a.file.read).to eq "contents"
  end
end
