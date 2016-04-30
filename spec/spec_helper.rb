require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

require 'bundler/setup'
require 'rspec'
require 'active_record'
require 'sqlite3'
require 'logger'

require File.expand_path("../../lib/saviour", __FILE__)

connection_opts = case ENV.fetch('DB', "sqlite")
                    when "sqlite"
                      {adapter: "sqlite3", database: ":memory:"}
                    when "mysql"
                      {adapter: "mysql2", database: "saviour", username: "root", encoding: "utf8"}
                    when "postgres"
                      {adapter: "postgresql", database: "saviour", username: "postgres"}
                  end

ActiveRecord::Base.establish_connection(connection_opts)

ActiveRecord::Base.logger = Logger.new(STDOUT) if ENV['DEBUG']
silence_stream(STDOUT) { require 'support/schema' }
require 'support/models'

RSpec.configure do |config|
  config.around do |example|
    Fog.mock!

    Dir.mktmpdir { |dir|
      @tmpdir = dir
      example.run
    }
  end

  config.after { Fog::Mock.reset }
end

def with_tempfile(ext = ".jpg")
  Tempfile.open(["random", ext], @tmpdir) do |temp|
    yield(temp)
  end
end

def with_test_file(name)
  file_path = File.join(File.expand_path("spec/support/data"), name)

  basename = File.basename file_path, ".*"
  Tempfile.open([basename, File.extname(file_path)], @tmpdir) do |temp|
    temp.write File.read(file_path)
    temp.flush
    temp.rewind

    yield(temp, File.basename(temp.path))
  end
end

class MockedS3Helper
  attr_reader :directory

  def start!(bucket_name: nil)
    @directory = connection.directories.create(key: bucket_name)
  end

  def write(contents, path)
    directory.files.create(
        key: path,
        body: contents,
        public: true
    )
  end

  def read(path)
    directory.files.get(path).body
  end

  def delete(path)
    directory.files.get(path).destroy
  end

  def head(path)
    directory.files.head(path)
  end

  def exists?(path)
    !!head(path)
  end

  def public_url(path)
    directory.files.get(path).public_url
  end

  private

  def connection
    @connection ||= Fog::Storage.new(provider: 'AWS', aws_access_key_id: "stub", aws_secret_access_key: "stub")
  end
end
