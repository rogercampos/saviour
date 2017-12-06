require 'spec_helper'

describe "halt processor behavior" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  let(:uploader) {
    Class.new(Saviour::BaseUploader) do
      store_dir { "/store/dir" }
      process { |_contents, _name| halt_process }
    end
  }

  let(:klass) {
    klass = Class.new(Test) {
      include Saviour::Model
    }
    klass.attach_file :file, uploader
    klass
  }

  it "does not write the file" do
    a = klass.create!

    expect(Saviour::Config.storage).to_not receive(:write)

    a.update_attributes! file: StringIO.new("contents")
    expect(a.reload.read_attribute(:file)).to be_nil
  end

  it "is considered as not persisted after save" do
    a = klass.new
    a.file = StringIO.new("contents")
    expect(a.file.persisted?).to be_falsey
    a.save
    expect(a.file.persisted?).to be_falsey
  end

  it "is considered as not dirty after save" do
    a = klass.new
    a.file = StringIO.new("contents")
    expect(a.file.changed?).to be_truthy
    a.save
    expect(a.file.changed?).to be_falsey
  end
end
