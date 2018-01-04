require 'saviour/version'
require 'saviour/base_uploader'
require 'saviour/file'
require 'saviour/local_storage'
require 'saviour/s3_storage'
require 'saviour/config'
require 'saviour/string_source'
require 'saviour/url_source'
require 'saviour/model'
require 'saviour/integrator'
require 'saviour/source_filename_extractor'
require 'saviour/life_cycle'
require 'saviour/persistence_layer'
require 'saviour/validator'
require 'saviour/db_helpers'

require 'tempfile'
require 'fileutils'

module Saviour
  NoActiveRecordDetected = Class.new(StandardError)
  FileNotPresent = Class.new(StandardError)
  ConfigurationError = Class.new(StandardError)
  SourceError = Class.new(StandardError)
  CannotCopy = Class.new(StandardError)
  MissingSource = Class.new(StandardError)
end
