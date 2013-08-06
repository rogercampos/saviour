[![Build Status](https://travis-ci.org/rogercampos/saviour.svg?branch=master)](https://travis-ci.org/rogercampos/saviour)

# Saviour

Saviour allows you to handle files attached to active record
models and stored in different backends. All backends work Fog,
any with  (local storage or s3 are the
ones currently supported). Just like Carrierwave or Paperclip, but
trying to solve different problems that those gems have:

- Just handle file storage, not image processing

- Don't break existing uploaded file paths when you change your code.
  Each stored file has all the data needed to connect to it stored in db

- No 'versions'. If you want versions, create a new attachment and use
  hooks to automatically update the second file when the first changes.

- Different APIs and different capabilities for each backend, you can't
  operate the same way with a local file than with a remote file.


## Installation

Add this line to your application's Gemfile:

    gem 'saviour'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install saviour

## Basic usage

You can declare attachments using `attach_file` with an existing text column
in the database.

    class Test < ActiveRecord::Base
      attach_file :file
    end

It should be a text column in order to have enough space to store all
the serialized data about your file: path, backend, metadata, etc.

You can further configure the attachment using a DSL in a block passed
to `attach_file`, for example:

    attach_file(:file) do |model|
      default_path "/uploads/#{model.class.to_s}/#{model.id}"
    end

All the possible configuration settings will be explained in the following
sections. You can use the following method to declare storages to use
later:

    # config/initializers/saviour.rb
    Saviour.configure do
      # Set default configurations here, will be used in all the
      # attach_file's.
    end

The file stored will follow the active record life cycle:

  * The file is saved on an `after_save` callback.
  * The file is removed on an `after_destroy` callback. The directory
    and possible parent directories will be also removed if left empty.

All the following actions and settings that you can use are performed in
order of definition. This means that a given action will receive the
input data from the file modified by a previous action. For instance,
using two consecutive `rename`'s, the second one will receive as
`original_filename` the name returned by the first one.


## Storages and backends

Saviour currently supports two backends identified as `:s3` and
`:local`. Those are the ways to store files that saviour knows about.
Then storages are defined as a specific way to store files in a backend,
providing all the required backend-specific settings. You can define
multiple storages and use them independently in your app. The `:file`
backend is an special case that needs no configuration at all and can
be used directly anywhere. Example:

    Saviour.configure do
      storage(:production) do |config|
        # fog settings + bucket
      end

      storage(:staging) do |config|
        # fog settings + bucket
      end
    end

    class Test < ActiveRecord::Base
      attach_file(:prod_file, on: :production) do
        # ...
      end

      attach_file(:staging_file, on: :staging) do
        # ...
      end
    end

This is an example of a class with two attachments, each one of them using
an storage defined earlier.

You can also use `default_storage :production` in the configure block,
and it will be used by default in all the `attach_file` calls if no
specified otherwise with the `:on` option.

All the files ever stored will remain available as long as the used
storage is still available in the app. When saving a file, the used
storage is persisted in the database and will used to retrieve the file.
However you can always override the storage name persisted in database
and try to retrieve the file with a different storage than the one used
to store it, as long as both used the same backend.

## Saving path

The file will be stored in the path defined with `default_path`:

    attach_file(:file) do |model|
      default_path "uploads/#{model.class}/#{model.id}"
    end

## Rename

You can rename the final file name using `rename`:

    attach_file(:file) do |model|
      rename { |original_name| "#{original_name[0..2]}-#{model.id}" }

      # you can also just pass a new filename if it's not dependent
      # on the original filename

      # rename "new_static_name"
      # rename model.name
    end

Note that the new filename must not include the extension part, that
will remain the same. The `original_name` in the block form will not
include the extension as well, but it's passed as a second argument if
needed:

    rename { |original_name, original_ext| "foo" }

## Change extension

You can handle extension changes just as name changes, using `extension`:

    attach_file(:file) do |model|
      extension { |original_ext| original_ext == "jpeg" ? "jpg" : "png" }
      # extension "png"
      # extension model.default_extension
    end

Just to be clear, this will just change the extension of the file,
not perform any kind of file format conversion. If you want to actually
perform modifications on the file, use Processors.

## Processors

Processors can be used to modify an attached file before being saved.
To give you some examples, you can use this to change an image format from
png to jpeg, to resize an image to an specific size (or other
transformations) or to compress the file using gzip before saving it.

    attach_file(:file) do |model|
      process do |file|
        # perform operations on the file object which is a Tempfile
        # instance

        # finally you must return a File instance representing the file
        # after transformations
      end

      # another form is with an existing method on the model
      process :compress
    end

The block passed to `process` will be executed in the context of the
instance.

## Validations

You can perform the following validations over the file to be saved:

    attach_file(:file) do
      validates_size less_than: 50.megabytes, greater_than: 1.megabyte
      validates_format in: [:csv, :txt]

      validates do |file|
        unless file.read[0..2] == "MX"
          errors.add(:file, "does not start with MX")
        end
      end

      # or just
      # validates :some_validation_of_mine
    end

The block passed to `validates` will be executed in the context of the
instance.

An additional `message:` option can be passed to the predefined
validations to override the default error messages, it follows the
default rails conventions on this regard.

## Automatic digest

An automatic digest of the file contents can be added to the filename
after beign saved, useful to expire possible caches on the stored files:

    attach_file(:file) do |model|
      # will append a default generated digest of 16 chars length
      digest

      # or you can manually give a digest
      digest do |file|
        Digest::MD5.hexdigest(file.read[0..100])
      end
    end

## Post processing hooks

## Using versions

## Metadata

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
