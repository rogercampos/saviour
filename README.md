[![Build Status](https://travis-ci.org/rogercampos/saviour.svg?branch=master)](https://travis-ci.org/rogercampos/saviour)
[![Code Climate](https://codeclimate.com/github/rogercampos/saviour/badges/gpa.svg)](https://codeclimate.com/github/rogercampos/saviour)
[![Test Coverage](https://codeclimate.com/github/rogercampos/saviour/badges/coverage.svg)](https://codeclimate.com/github/rogercampos/saviour/coverage)

# Saviour

This is a small library that handles file uploads and nothing more. It integrates with ActiveRecord and manages file
storage following the active record instance lifecycle.


<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Intro](#intro)
- [Basic usage example](#basic-usage-example)
- [File API](#file-api)
- [Storage abstraction](#storage-abstraction)
  - [public_url](#public_url)
  - [LocalStorage](#localstorage)
  - [S3Storage](#s3storage)
- [Source abstraction](#source-abstraction)
  - [StringSource](#stringsource)
  - [UrlSource](#urlsource)
- [Uploader classes and Processors](#uploader-classes-and-processors)
  - [store_dir](#store_dir)
  - [Accessing model and attached_as](#accessing-model-and-attached_as)
  - [Processors](#processors)
- [Versions](#versions)
- [Validations](#validations)
- [Active Record Lifecycle integration](#active-record-lifecycle-integration)
- [FAQ](#faq)
  - [Digested filename](#digested-filename)
  - [Getting metadata from the file](#getting-metadata-from-the-file)
  - [How to recreate versions](#how-to-recreate-versions)
  - [Caching across redisplays in normal forms](#caching-across-redisplays-in-normal-forms)
  - [Introspection (Class.attached_files)](#introspection-classattached_files)
  - [Processing in background](#processing-in-background)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->


## Intro

The goal of this library is to be as minimal as possible, including as less features and code the better. This library's
responsibility is to handle the storage of a file related to an ActiveRecord object, persisting the file on save and
deleting it on destroy. Therefore, there is no code included to handle images, integration with rails views or any
other related feature. There is however a FAQ section later on in this README that can help you implement those things
using Saviour and your own code.


## Basic usage example

This library is inspired api-wise by carrierwave, sharing the same way of declaring "attachments" (file storages related
to an ActiveRecord object) and processings. See the following example of a model including a file:

```
class Post < ActiveRecord::Base
  include Saviour::Model

  # The posts table must have an `image` string column.
  attach_file :image, PostImageUploader
end

class PostImageUploader < Saviour::BaseUploader
  store_dir { "/default/path/#{model.id}/#{attached_as}" }

  process :resize, width: 500, height: 500

  version(:thumb) do
    process :resize, width: 100, height: 100
  end

  def resize(contents, filename, opts)
    width = opts[:width]
    height = opts[:height]

    # modify contents in memory here
    contents = user_implementation_of_resize(contents, width, height)

    [contents, filename]
  end
end
```

In this example we have posts that have an image. That image will be stored in a path like `/default/path/<id>/image`
and also a resize operation will be performed before persisting the file.

There's one version declared with the name `thumb` that will be created by resizing the file to 100x100. The version
filename will be by default `<original_filename>_thumb` but it can be changed if you want.

Filenames (both for the original image and for the versions) can be changed in a processor just by returning a different
second argument.

Here the resize manipulation is done in-memory, but there're also a way to handle manipulations done at the file level if
you need to use external binaries like imagemagick, image optimization tools (pngquant, jpegotim, etc...) or others.


## File API

`Saviour::File` is the type of object you'll get when accessing the attribute over which a file is attached in the
ActiveRecord object. The public api you can use on those objects is:

- assign
- exists?
- read
- write
- delete
- public_url
- url
- changed?
- filename
- with_copy
- blank?

Use `assign` to assign a file to be stored. You can use any object that responds to `read`. See below the section
about Sources abstraction for further info.

`exists?`, `read`, `write`, `delete` and `public_url` are delegated to the storage, with the exception of `write` that
is channeled with the uploader first to handle processings. `url` is just an alias for `public_url`.

`changed?` indicates if the file has changed, in memory, regarding it's initial value. It's equivalent to the `changed?`
method that ActiveRecord implements on database columns.

`filename` is the filename of the currently stored file. Only works for files that have been already stored, not assigned.

`blank?` indicates if the file is present either in the persistence layer or in memory. It provides api-compatibility with
default rails validations like `validates_presence_of`.

`with_copy` is a helper method that will read the persisted file, create a copy using a `Tempfile` and call the block
passed to the method with that Tempfile. Will clean afterwards.

As mentioned before, you can access a `File` object via the name of the attached_as, from the previous example you could do:

```
post = Post.find(123)
post.image # => <Saviour::File>
```

You can also get the `File` instance of version by using an argument matching the version name:

```
post = Post.find(123)
post.image # => <Saviour::File>
post.image(:thumb) # => <Saviour::File>
```

Finally, a couple of convenient methods are also added to the ActiveRecord object that just delegate to the `File` object:

```
post = Post.find(123)
post.image = File.open("/my/image.jpg") # This is equivalent to post.image.assign(File.open(...))
post.image_changed? # This is equivalent to post.image.changed?
```

## Storage abstraction

Storages are classes responsible for handling the persistence layer with the underlying persistence provider, whatever
that is. Storages are considered public API and anyone can write a new one. Included in the Library there are two of them,
LocalStorage and S3Storage. To be an Storage, a class must implement the following api:

```
def write(contents, path)
end

def read(path)
end

def exists?(path)
end

def delete(path)
end
```

The convention here is that a file consist of a raw content and a path representing its location within the underlying
persistence layer.

You must configure Saviour by providing the storage to use:

```
Saviour::Config.storage = MyStorageImplementation.new
```

The provided storage object is considered a global configuration state that will be used by Saviour for all mounters.
However, this configuration is thread-safe and can be changed at runtime, allowing you in practice to work with different
storages by swapping them depending on your use case.


### public_url

Storages can optionally also implement this method, in order to provide a public URL to the stored file without going
through the application code.

For example, if you're storing files in a machine with a webserver, you may want this method to convert from a local
path to an external URL, adding the domain and protocol parts. As an ilustrative example:

```
def public_url(path)
  "http://mydomain.com/files/#{path}"
end
```


### LocalStorage

You can use this storage to store files in the local machine running the code. Example:

```
Saviour::Config.storage = Saviour::LocalStorage.new(
  local_prefix: "/var/www/app_name/current/files",
  public_url_prefix: "http://mydomain.com/uploads"
)
```

The `local_prefix` option is mandatory, and defines the base prefix under which the storage will store files in the
machine. You need to configure this accordingly to your use case and deployment strategies, for example, for rails
and capistrano with default settings you'll need to set it to `Rails.root.join("public/system")`.

The `public_url_prefix` is optional and should represent the public endpoint from which you'll serve the assets.
Same as before, you'll need to configure this accordingly to your deployment specifics.
You can also assign a Proc instead of a String to dynamically manage this (for multiple asset hosts for example).

This storage will take care of removing empty folders after removing files.

This storage includes a feature of overwrite protection, raising an exception if an attempt is made of writing something
on a path that already exists. This behaviour in enabled by default, but you can turn it off by passing an additional
argument when instantiating the storage: `overwrite_protection: false`.


### S3Storage

An storage implementation using `Fog::AWS` to talk with Amazon S3. Example:

```
Saviour::Config.storage = Saviour::S3Storage.new(
  bucket: "my-bucket-name",
  aws_access_key_id: "stub",
  aws_secret_access_key: "stub"
)
```

All passed options except for `bucket` will be directly forwarded to the initialization of `Fog::Storage.new(opts)`,
so please refer to Fog/AWS [source](https://github.com/fog/fog-aws/blob/master/lib/fog/aws/storage.rb) for extra options.

The `public_url` method just delegates to the Fog implementation, which will provide the default path to the file,
for example `https://fake-bucket.s3.amazonaws.com/dest/file.txt`. Custom domains can be configured directly in Fog via
the `host` option, as well as `region`, etc.

The `exists?` method uses a head request to verify existence, so it doesn't actually download the file.

All files will be created as public by default, but you can set an additional argument when initializing the storage to
declare options to be used when creating files to S3, and those options will take precedence. Use this for example to
set an expiration time for the asset. Example:

```
Saviour::Config.storage = Saviour::S3Storage.new(
  bucket: "my-bucket-name",
  aws_access_key_id: "stub",
  aws_secret_access_key: "stub",
  create_options: {public: false, 'Cache-Control' => 'max-age=31536000'}
)
```

This storage includes a feature of overwrite protection, raising an exception if an attempt is made of writing something
on a path that already exists. This behaviour in enabled by default, but you can turn it off by passing an additional
argument when instantiating the storage: `overwrite_protection: false`. This feature requires an additional HEAD request
to verify existence for every write.


## Source abstraction

As mentioned before, you can use `File#assign` with any object that responds to `read`. This is already the case for `::File`,
`Tempfile` or `IO`. Since a file requires also a filename, however, in those cases a random filename will be assigned
(you can always set the filename using a processor later on).

Additionally, if the object responds to `#original_filename` then that will be used as a filename instead of generating
a random one.

You can create your own classes implementing this API to extend functionality. This library includes two of them: StringSource
and UrlSource.


### StringSource

This is just a wrapper class that gives no additional behavior except for implementing the required API. Use it as:

```
foo = Saviour::StringSource.new("my raw contents", "filename.jpg")
post = Post.find(123)
post.image = foo
```

### UrlSource

This class implements the source abstraction from a URL. The `read` method will download the given URL and use those
contents. The filename will be guessed as well from the URL. Redirects will be followed (max 10) and connection retried
3 times before raising an exception. Example:

```
foo = Saviour::UrlSource.new("http://server.com/path/image.jpg")
post = Post.find(123)
post.image = foo
```


## Uploader classes and Processors

Uploaders are the classes responsible for managing what happens when a file is uploaded into an storage. Use them to define
the path that will be used to store the file, additional processings that you want to run and versions. See a complete
example:

```
class ExampleUploader < Saviour::BaseUploader
  store_dir { "/default/path/#{model.id}" }

  process :resize, width: 50, height: 50

  process_with_file do |local_file, filename|
    `mogrify -resize 40x40 #{local_file.path}`
    [local_file, filename]
  end

  process do |contents, filename|
    [contents, "new-#{filename}"]
  end

  version(:thumb) do
    store_dir { "/default/path/#{model.id}/versions" }
    process :resize, with: 10, height: 10
  end

  version(:just_a_copy)

  def resize(contents, filename, opts)
    # User RMagick to modify contents in memory here
    [contents, filename]
  end
end
```

### store_dir

Use `store_dir` to indicate the default directory under which the file will be stored. You can also use it under a
`version` to change the default directory for that specific version.


### Accessing model and attached_as

Both `store_dir` and `process` / `process_with_file` declarations can be expressed passing a block or passing a symbol
representing a method. In both cases, you can directly access there a method called `model` and a method called
`attached_as`, representing the original model and the name under which the file is attached to the model.

Use this to get info form the model to compose the store_dir, for example, or even to create a processor that
extracts information from the file and passes this info back to the model to store it in additional db columns.

### Processors

Processors are the methods (or blocks) that will modify either the file contents or the filename before actually
upload the file into the storage. You can declare them via the `process` or the `process_with_file` method.

They work as a stack, chaining the response from the previous one as input for the next one, and are executed in the
same order you declare them. Each processor will receive the raw contents and the filename, and must return an array
with two values, the new contents and the new filename.

As described in the example before, processors can be declared in two ways:

- As a symbol or a string, it will be interpreted as a method that will be called in the current uploader.
  You can optionally set an extra Hash of options that will be forwarded to the method, so it becomes easier to reuse processors.

- As a Proc, for inline use cases.

By default processors work with the full raw contents of the file, and that's what you will get and must return when
using the `process` method. However, since there are use cases for which is more convenient to have a File object
instead of the raw contents, you can also use the `process_with_file` method, which will give you a Tempfile object,
and from which you must return a File object as well.

You can combine both and Saviour will take care of synchronization, however take into account that every time you
switch from one to another there will be a penalty for having to either read or write from/to disk.
Internally Saviour works with raw contents, so even if you only use `process_with_file`, there will be a penalty at the
beginning and at the end, for writing and reading to and from a file.

When using `process_with_file`, the last file instance you return from your last processor defined as
`process_with_file` will be automatically deleted by Saviour. Be aware of this if you return
some File instance different than the one you received pointing to a file.

Finally, processors can be disabled entirely via a configuration parameter. Example:

```
Saviour::Config.processing_enabled = false
Saviour::Config.processing_enabled = true
```

You can use this when running tests, for example, or if you want processors to not execute for some reason. The flag can be
changed in real time and is thread-safe.


## Versions

Versions in Saviour are treated just like an additional attachment. They require you an additional database column to
persist the file path, and this means you can work with them completely independently of the main file. They can be
assigned, deleted, etc... independently. You just need to work with the versioned `Saviour::File` instance instead of the main
one, so for example when assigning a file you'll need to do `object.file(:thumb).assign(my_file)`.

You must create an additional database String column for each version, with the following convention:

`<attached_as>_<version_name>`

The only feature versions gives you is following their main file: A version will be assigned automatically if you assign the
main file, and all versions will be deleted when deleting the main file.

In case of conflict, the versioned assignation will be preserved. For example, if you assign both the main file and the version,
both of them will be respected and the main file will not propagate to the version in this case.

Defined processors in the Uploader will execute when assigning a version directly. Validations will also execute when assigning
a version directly (see validation section for details).

When you open a `version` block within an uploader, you can declare some processors (or change the store dir) only for
that version. Note that all processors will be executed for every version that exists, plus one time for the base file.
There are no optimizations done, if your uploader declares one processors first, and from there you open 2 versions,
the first processors will be executed 3 times.


## Validations

You can declare validations on your model to implement specific checkings over the contents or the filename of an attachment.

Take note that validations are executed over the contents given as they are, before any processing. For example you can
have a validation declaring "max file size is 1Mb", assign a file right below the limit, but then process it in a way that
increases its size. You'll be left with a file bigger than 1Mb.

Example of validations:

```
class Post < ActiveRecord::Base
  include Saviour::Model
  attach_file :image, PostImageUploader

  attach_validation(:image) do |contents, filename|
    errors.add(:image, "must be smaller than 10Mb") if contents.bytesize >= 10.megabytes
    errors.add(:image, "must be a jpeg file") if File.extname(filename) != ".jpg" # naive, don't copy paste
  end
end
```

Validations will always receive the raw contents of the file. If you need to work with a `File` object you'll need to implement
the necessary conversions.

Validations can also be declared passing a method name instead of a block, like this:

```
class Post < ActiveRecord::Base
  include Saviour::Model
  attach_file :image, PostImageUploader
  attach_validation :image, :check_size

  private

  def check_size(contents, filename)
    errors.add(:image, "must be smaller than 10Mb") if contents.bytesize >= 10.megabytes
  end
end
```

To improve reusability, validation blocks or methods will also receive a third argument (only if declared in your
implementation). This third argument is a hash containing `attached_as` and `version` of the validating file.


## Active Record Lifecycle integration

On `after_save` Saviour will upload the changed files attached to the current model, executing the processors as needed.

On `after_destroy` Saviour will delete all the attached files and versions.

On `validate` Saviour will execute the validations defined.

When validations are defined, the assigned source will be readed only once. On validation time, it will be readed, passed
to the validation blocks and cached. If the model is valid, the upload will happen from those cached contents. If there
are no validations, the source will be readed only on upload time, after validating the model.


## FAQ

This is a compilation of common questions or features regarding file uploads.

### Digested filename

A common use case is to create a processor to include a digest of the file in the filename, in order to automatically
expire caches. The implementation is left for the user, but a simple example of such processor is this:

```
  def digest_filename(contents, filename, opts = {})
    separator = opts.fetch(:separator, "-")

    digest = ::Digest::MD5.hexdigest(contents)
    extension = ::File.extname(filename)

    new_filename = "#{[::File.basename(filename, ".*"), digest].join(separator)}#{extension}"

    [contents, new_filename]
  end
```

### How to recreate versions

Recreating a version based on the master file can be easily done by just assigning the master file to the version and
saving the model. You just need a little bit more code in order to preserve the current version filename, for example,
if that's something you want.

An example service that can do that is the following:

```
class SaviourRecreateVersionsService
  def initialize(model)
    @model = model
  end

  def recreate!(attached_as, *versions)
    base = @model.send(attached_as).read

    versions.each do |version|
      current_filename = @model.send(attached_as, version).filename
      @model.send(attached_as, version).assign(Saviour::StringSource.new(base, current_filename))
    end

    @model.save!
  end
end
```

### Getting metadata from the file

### Caching across redisplays in normal forms
### Introspection (Class.attached_files)
### Processing in background
