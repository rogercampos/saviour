require 'spec_helper'

describe "memory usage" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  let(:base_klass) {
    a = Class.new(Test) { include Saviour::Model }
    a.attach_file :file, uploader
    a
  }

  let(:size_to_test) { 10 } # Test with 10Mb files

  def with_tempfile
    f = Tempfile.new "test"

    size_to_test.times do
      1024.times do
        f.write SecureRandom.hex(512)
      end
    end
    f.flush

    begin
      yield f
    ensure
      f.close!
    end
  end

  def with_no_gc
    GC.disable
    yield
  ensure
    GC.enable
  end

  describe "is kept low when using exclusively with_file processors" do
    let(:uploader) {
      Class.new(Saviour::BaseUploader) {
        store_dir { "/store/dir" }

        process_with_file do |file, filename|
          digest = Digest::MD5.file(file.path).hexdigest
          [file, "#{digest}-#{filename}"]
        end
      }
    }

    it do
      a = base_klass.create!

      with_tempfile do |f|
        with_no_gc do
          base_line = GetProcessMem.new.mb

          a.update! file: f

          expect(GetProcessMem.new.mb - base_line).to be < 3
        end
      end
    end
  end

  describe "increases to file size when using in memory processors" do
    let(:uploader) {
      Class.new(Saviour::BaseUploader) {
        store_dir { "/store/dir" }

        process do |contents, filename|
          digest = Digest::MD5.hexdigest(contents)

          [contents, "#{digest}-#{filename}"]
        end
      }
    }

    it do
      with_tempfile do |f|
        with_no_gc do
          a = base_klass.create!

          base_line = GetProcessMem.new.mb

          a.update! file: f
          # Expect memory usage to grow at least half the file size
          expect(GetProcessMem.new.mb - base_line).to be >= size_to_test / 2
        end
      end
    end
  end
end
