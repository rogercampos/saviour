[![Build Status](https://travis-ci.org/rogercampos/saviour.svg?branch=master)](https://travis-ci.org/rogercampos/saviour)

# Saviour

This is a very small library that only handles file uploading. It does not integrate with Rails (only ActiveRecord), it is not integrated with image manipulation (mini magick, dragonfly or other) and it is not integrated with rails views or anything else.

## Storages

The storage is the component responsible for talking with the real backend that you'll use to store your files.

It can be any object implementing the following api:

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
The storage is responsible for ensuring the persistence and correct behaviour of the operations described. Saviour comes with two basic implementations for LocalStorage (storing files in the machine running your code) and S3Storage (using amazon s3 as backend), but you can write your own as well.

The basic convention is that a file consist of a raw content (a string, maybe binary) and a path (a string) representing its location within the backing store.

You must configure Saviour by providing the storage to use, using:

```
Saviour::Config.storage = MyStorageImplementation.new
```
The provided storage object will be used for all the lifespan of the runnig application, for all the file uploads handled by Saviour. However, if you change it at runtime it will work as expected, there's no internal caching on this.

### public_url

Storages can optionally also implement this method, in order to provide a public URL to the stored file without going through the application code.

For example, if you're storing files in a machine with a webserver, you may want this method to convert from a local path to an external URL, adding the domain and protocol parts. As an ilustrative example:

```
def public_url(path)
  "http://mydomain.com/files/#{path}"
end
```
Http is the obvious example, but you can really work with any scheme, for example you can create a Storage to persist files into an FTP server and implement this to convert the internal path into something like `ftp://ftpserver.com/path/file.txt`



### LocalStorage

You can use this storage to store files in the local machine running the code. Example:

```
Saviour::Config.storage = Saviour::LocalStorage.new(
  local_prefix: "/var/www/app_name/current/files",
  public_url_prefix: "http://mydomain.com/uploads"
)
```

The `local_prefix` option is mandatory, and defines the base prefix under which the storage will store files in the machine. You need to configure this accordingly to your use case and deployment strategies, for example, for rails and capistrano with default settings you'll need to set it to `Rails.root.join("public/system")`.

The `public_url_prefix` is optional, and if provided you'll be able to use the `public_url` method, which will compose the provided public prefix with the given path. Same as before, you'll need to configure this accordingly to your deployment specifics.

As a bonus behaviour, this storage will take care of removing empty folders after removing files.


### S3Storage

An storage implementation using `Fog::AWS` to talk with Amazon S3. Example:

```
Saviour::Config.storage = Saviour::S3Storage.new(
  bucket: "my-bucket-name",
  aws_access_key_id: "stub",
  aws_secret_access_key: "stub"
)
```

All passed options except for `bucket` will be directly forwarded to the initialization of `Fog::Storage.new(opts)`, so please refer to Fog/AWS [source](https://github.com/fog/fog-aws/blob/master/lib/fog/aws/storage.rb) for extra options.

The `public_url` method just delegates to the Fog implementation, which will provide the default path to the file, for example `https://fake-bucket.s3.amazonaws.com/dest/file.txt`. Custom domains can be configured directly in Fog via the `host` option, as well as `region`, etc.

The `exists?` method uses a head request to verify existance, so it doesn't actually download the file.

All files will be created as public.


## Uploaders

Uploaders are the components responsible for deciding what happens when you want to upload a file. It manages 3 things:

- Set the base dir under which the given file (with the given filename) will be stored.
- Declare processings to run before upload, to modify either the contents or the filename of the file.
- Declare versioned processings. This acts as a namespacing for the two previous responsabilities, so they only apply when the uploader is managing a versioned file.

An uploader is a `Class` inheriting from `Saviour::BaseUploader`. The previous responsabilities are expressed using a minimal DSL, while you can use methods and standard ruby (including modules, etc...) to organize your processing code. See a full example here, explanation follows:

```
class ExampleUploader < Saviour::BaseUploader
  store_dir! { "/default/path/#{model.id}" }

  run :resize, width: 50, height: 50

  run_with_file do |local_file, filename|
    `mogrify -resize 40x40 #{local_file.path}`
    [local_file, filename]
  end

  run do |contents, filename|
    [contents, "new-#{filename}"]
  end

  version(:thumb) do
    store_dir! { "/default/path/#{model.id}/versions" }
    run :resize, with: 10, height: 10
  end

  version(:just_a_copy)

  def resize(contents, filename, opts)
    # User RMagick to modify contents in memory here
    [contents, filename]
  end
end
```

### Accessing model and attached_as

Both `store_dir` and `run` / `run_with_file` declarations can be expressed passing a block, or passing a symbol representing a method. In both cases, you can directly access there a method called `model` and a method called `attached_as`, representing the original model and the name under which the file is attached to the model.

Use this to get info form the model to compose the store_dir, for example, or even to create a processor that extracts information from the file and passes this info back to the model.


### store_dir

Use `store_dir` to indicate the default directory under which the file will be stored. You can also use it under a `version` to change the default directory for that specific version.


### Processors

Processors are the methods (or blocks) that will modifiy either the file contents or the filename before actually upload the file into the storage. You can declare them via the `run` or the `run_with_file` method.

They work as a stack, chaining the response from the previous one as input for the next one, and are executed in the same order you declare them. Each processor will receive the raw contents and the filename, and must return an array with two values, the new contents and the new filename.

As described in the example before, processors can be declared in two ways:

- As a symbol or a string, it will be interpreted as a method that will be called in the current uploader. You can optionally set an extra Hash of options that will be forwarded to the method, so it becomes easier to reuse processors.
- As a lambda, for inline use cases.


By default processors work with the full raw contents of the file, and that's what you will get and must return when using the `run` method. However, since there are use cases for which is more convinient to have a File object instead of the raw contents, you can also use the `run_with_file` method, which will give you a Tempfile object, and from which you must return a File object as well.

You can combine both and Saviour will take care of synchronization, however take into account that every time you switch from one to another there will be a penalty for having to either read or write from/to disk. Internally Saviour works with raw contents, so even if you only use `run_with_file`, there will be a penalty at the beginning and at the end, for writing and reading to and from a file.

When using `run_with_file`, the last file instance you return from your last processor defined as `run_with_file` will be automatically deleted by Saviour. However, if from any of those processors you return some File instance different than the one you received pointing to a different tempfile (or file), it's your responsability to clear it.


### Versions

When you open a `version` block within an uploader, you can declare some processors (or change the store dir) only for that version. Note that all processors will be executed for every version that exists, plus one time for the base file. There are no optimizations done here, if your uploader declares one processors first, and from there you open 2 versions, the first processors will be executed 3 times.

In Saviour versions are treated just like the base file, as you can read later on in this documentation you can assign, write or manipulate a version directly, independently from the original file. So, you can see uploader version declarations just as a way to isolate some processors so that they are run only when the uploader is used to upload a version to a storage, instead of the base file.


### Digest calculation

Saviour comes with one processor that calculates the md5 checksum of the contents and append the result into the filename. You can use it in order to automatically expire possible caches present in CDNs or intermediate http proxy caches. Use it like this:

```
class ExampleUploader < Saviour::BaseUploader
  include Saviour::Processors:Digest

  run :digest_filename, separator: "-"
end
```
The previous example will change a filename like `file.jpeg` to `file-17a9172b91198028.jpeg`. You can optionally set the separator character, by default is `-`.


## ActiveRecord

### Sources

UrlSource and StringSource, and anything else.

### Validations
### Declaring versions
###