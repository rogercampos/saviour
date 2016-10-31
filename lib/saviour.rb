require 'fileutils'
require 'digest/md5'
require 'active_support/concern'
require 'active_support/core_ext'
require 'active_support/core_ext/module/attribute_accessors'
require 'fog/aws'

require 'saviour/processors/digest'

require 'saviour/version'
require 'saviour/base_uploader'
require 'saviour/file'
require 'saviour/local_storage'
require 'saviour/s3_storage'
require 'saviour/config'
require 'saviour/string_source'
require 'saviour/url_source'
require 'saviour/model'

module Saviour
  NoActiveRecordDetected = Class.new(StandardError)
end
