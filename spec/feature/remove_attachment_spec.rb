require 'spec_helper'

describe "remove attachment" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  let(:uploader) {
    Class.new(Saviour::BaseUploader) {
      store_dir { "/store/dir/#{model.id}/#{attached_as}" }
    }
  }

  let(:klass) {
    a = Class.new(Test) { include Saviour::Model }
    a.attach_file :file, uploader
    a
  }

  context "without a transaction" do
    it 'removes associated file and column when persisted' do
      a = klass.create! file: Saviour::StringSource.new("Some contents", "filename.txt")

      expect(a.file.read).to eq "Some contents"

      a.remove_file!

      expect(a.file.read).to be_falsey
      expect(a[:file]).to be_nil
    end

    it 'removes associated file and column when file not persisted' do
      a = klass.create!

      a.file = Saviour::StringSource.new("Some contents", "filename.txt")

      a.remove_file!

      expect(a.file.read).to be_falsey
      expect(a[:file]).to be_nil
    end
  end

  context "within a transaction" do
    it "does not remove file and column on rollback" do
      a = klass.create! file: Saviour::StringSource.new("Some contents", "filename.txt")

      expect(a.file.read).to eq "Some contents"

      ActiveRecord::Base.transaction do
        a.remove_file!
        raise ActiveRecord::Rollback
      end

      expect(a.file.read).to eq "Some contents"
      expect(a[:file]).to be_present
    end

    it "removes associated file and column on commit" do
      a = klass.create! file: Saviour::StringSource.new("Some contents", "filename.txt")

      expect(a.file.read).to eq "Some contents"

      ActiveRecord::Base.transaction do
        a.remove_file!
        expect(a.file.read).to eq "Some contents"
      end

      expect(a.file.read).to be_falsey
      expect(a[:file]).to be_nil
    end

    it "removes associated file and column on commit on non-persisted file" do
      a = klass.create!
      a.file = Saviour::StringSource.new("Some contents", "filename.txt")

      ActiveRecord::Base.transaction do
        a.remove_file!
      end

      expect(a.file.read).to be_falsey
      expect(a[:file]).to be_nil
    end
  end

  context "with followers" do
    context "when configured to destroy followers" do
      let(:klass) {
        a = Class.new(Test) { include Saviour::Model }
        a.attach_file :file, uploader
        a.attach_file :file_thumb, uploader, follow: :file, dependent: :destroy
        a
      }

      it "does not remove followers when using dependent: :ignore on the remove call" do
        a = klass.create! file: StringIO.new("some contents without a filename")
        expect(a.file_thumb.read).to eq "some contents without a filename"

        a.remove_file!(dependent: :ignore)

        expect(a.file_thumb?).to be_truthy
        expect(a.file_thumb.read).to eq "some contents without a filename"
        expect(a.file?).to be_falsey
      end
    end

    context "when configured to ignore followers" do
      let(:klass) {
        a = Class.new(Test) { include Saviour::Model }
        a.attach_file :file, uploader
        a.attach_file :file_thumb, uploader, follow: :file, dependent: :ignore
        a
      }

      it "does remove followers when using dependent: :destroy on the remove call" do
        a = klass.create! file: StringIO.new("some contents without a filename")
        expect(a.file_thumb.read).to eq "some contents without a filename"

        a.remove_file!(dependent: :destroy)

        expect(a.file_thumb?).to be_falsey
        expect(a.file_thumb.read).to be_nil
        expect(a.file?).to be_falsey
      end
    end
  end
end
