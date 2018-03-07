require 'spec_helper'

describe "concurrent processors" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  WAIT_TIME = 1
  WITHIN_MARGIN = WAIT_TIME * 0.2 # 20% margin

  let(:uploader) {
    Class.new(Saviour::BaseUploader) {
      store_dir { "/store/dir" }

      process_with_file do |file, filename|
        sleep WAIT_TIME

        [file, filename]
      end
    }
  }

  let(:klass) {
    klass = Class.new(Test) { include Saviour::Model }
    klass.attach_file :file, uploader
    klass.attach_file :file_thumb, uploader
    klass.attach_file :file_thumb_2, uploader
    klass.attach_file :file_thumb_3, uploader
    klass
  }

  context 'on update' do
    it 'works concurrently with 4 workers' do
      a = klass.create!

      Saviour::Config.concurrent_workers = 4

      t0 = Time.now
      a.update_attributes! file: Saviour::StringSource.new("contents", "file.txt"),
                           file_thumb: Saviour::StringSource.new("contents", "file_2.txt"),
                           file_thumb_2: Saviour::StringSource.new("contents", "file_3.txt"),
                           file_thumb_3: Saviour::StringSource.new("contents", "file_4.txt")

      diff = Time.now - t0
      expect(diff).to be_within(WITHIN_MARGIN).of(WAIT_TIME)
      expect(diff).to be < WAIT_TIME * 4
    end

    it 'works in serial with 1 worker' do
      a = klass.create!

      Saviour::Config.concurrent_workers = 1

      t0 = Time.now
      a.update_attributes! file: Saviour::StringSource.new("contents", "file.txt"),
                           file_thumb: Saviour::StringSource.new("contents", "file_2.txt"),
                           file_thumb_2: Saviour::StringSource.new("contents", "file_3.txt"),
                           file_thumb_3: Saviour::StringSource.new("contents", "file_4.txt")

      expect(Time.now - t0).to be >= WAIT_TIME * 4
    end

    it 'concurrency can be adjusted' do
      a = klass.create!

      Saviour::Config.concurrent_workers = 2

      t0 = Time.now
      a.update_attributes! file: Saviour::StringSource.new("contents", "file.txt"),
                           file_thumb: Saviour::StringSource.new("contents", "file_2.txt"),
                           file_thumb_2: Saviour::StringSource.new("contents", "file_3.txt"),
                           file_thumb_3: Saviour::StringSource.new("contents", "file_4.txt")

      diff = Time.now - t0
      expect(diff).to be_within(WITHIN_MARGIN).of(WAIT_TIME * 2)
      expect(diff).to be < WAIT_TIME * 4
    end
  end

  context 'on create' do
    it 'works concurrently with 4 workers' do
      Saviour::Config.concurrent_workers = 4

      t0 = Time.now
      klass.create! file: Saviour::StringSource.new("contents", "file.txt"),
                    file_thumb: Saviour::StringSource.new("contents", "file_2.txt"),
                    file_thumb_2: Saviour::StringSource.new("contents", "file_3.txt"),
                    file_thumb_3: Saviour::StringSource.new("contents", "file_4.txt")

      diff = Time.now - t0
      expect(diff).to be_within(WITHIN_MARGIN).of(WAIT_TIME)
      expect(diff).to be < WAIT_TIME * 4
    end

    it 'works in serial with 1 worker' do
      Saviour::Config.concurrent_workers = 1

      t0 = Time.now
      klass.create! file: Saviour::StringSource.new("contents", "file.txt"),
                    file_thumb: Saviour::StringSource.new("contents", "file_2.txt"),
                    file_thumb_2: Saviour::StringSource.new("contents", "file_3.txt"),
                    file_thumb_3: Saviour::StringSource.new("contents", "file_4.txt")

      expect(Time.now - t0).to be >= WAIT_TIME * 4
    end

    it 'concurrency can be adjusted' do
      Saviour::Config.concurrent_workers = 2

      t0 = Time.now
      klass.create! file: Saviour::StringSource.new("contents", "file.txt"),
                    file_thumb: Saviour::StringSource.new("contents", "file_2.txt"),
                    file_thumb_2: Saviour::StringSource.new("contents", "file_3.txt"),
                    file_thumb_3: Saviour::StringSource.new("contents", "file_4.txt")

      diff = Time.now - t0
      expect(diff).to be_within(WITHIN_MARGIN).of(WAIT_TIME * 2)
      expect(diff).to be < WAIT_TIME * 4
    end
  end
end