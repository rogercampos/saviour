[![Build Status](https://travis-ci.org/rogercampos/saviour.svg?branch=master)](https://travis-ci.org/rogercampos/saviour)
[![Code Climate](https://codeclimate.com/github/rogercampos/saviour/badges/gpa.svg)](https://codeclimate.com/github/rogercampos/saviour)
[![Test Coverage](https://codeclimate.com/github/rogercampos/saviour/badges/coverage.svg)](https://codeclimate.com/github/rogercampos/saviour/coverage)

# Saviour

Saviour is a tool to help you manage files attached to Active Record models. It tries to be minimal about the
use cases it covers, but with a deep and complete coverage on the ones it does. For example, it offers
no support for image manipulation, but it does implement dirty tracking and transactional-aware behavior.  

It also tries to have a flexible design, so that additional features can be added by the user on top of it.
You can see an example of such typical features on the [FAQ section at the end of this document](#faq).


## Motivation

This project started in 2015 as an attempt to replace Carrierwave. Since then other solutions have appeared
to solve the same problem, like [shrine](https://github.com/shrinerb/shrine), [refile](https://github.com/refile/refile)
and even more recently rails own solution [activestorage](https://github.com/rails/rails/tree/master/activestorage).

The main difference between those solutions and Saviour is about the broadness and scope of the problem
that wants to be solved.

They offer a complete out-of-the-box solution that covers many different needs:
image management, caching of files for seamless integration with html forms, direct uploads to s3, metadata
extraction, background jobs integration or support for different ORMs are some of the features you can find on
those libraries. 

If you need those functionalities and they suit your needs, they can be perfect solutions for you.

The counterpart, however, is that they have more dependencies and, as they cover a broader spectrum of
use cases, they tend to impose more conventions that are expected to be followed as is. If you don't want, 
or can't follow some of those conventions then you're out of luck.

Saviour provides a battle-tested infrastructure for storing files following an AR model 
life-cycle which can be easily extended to suit your custom needs.



## Installation

Add this line to your application's Gemfile:

```ruby
gem 'saviour'
```

And then execute:

    $ bundle


<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Quick start](#quick-start)
  - [General Usage](#general-usage)
    - [Api on attachment](#api-on-attachment)
    - [Additional api on the model](#additional-api-on-the-model)
  - [Storages](#storages)
    - [Local Storage](#local-storage)
    - [S3 Storage](#s3-storage)
  - [Uploader classes](#uploader-classes)
    - [store_dir](#store_dir)
    - [Processors](#processors)
      - [halt_process](#halt_process)
  - [Versions](#versions)
  - [Transactional behavior](#transactional-behavior)
  - [Concurrency](#concurrency)
    - [stash](#stash)
  - [Dirty tracking](#dirty-tracking)
  - [AR Validations](#ar-validations)
  - [Introspection](#introspection)
- [Extras & Advance usage](#extras--advance-usage)
  - [Skip processors](#skip-processors)
  - [Testing](#testing)
  - [Sources: url and string](#sources-url-and-string)
  - [Custom Storages](#custom-storages)
  - [Bypassing Saviour](#bypassing-saviour)
      - [Bypass example: Nested Cloning](#bypass-example-nested-cloning)
- [FAQ](#faq)
  - [how to reuse code in your app, attachment with defaults](#how-to-reuse-code-in-your-app-attachment-with-defaults)
  - [How to manage file removal from forms](#how-to-manage-file-removal-from-forms)
  - [How to extract metadata from files](#how-to-extract-metadata-from-files)
  - [How to process files in background / delayed](#how-to-process-files-in-background--delayed)
  - [How to recreate versions](#how-to-recreate-versions)
  - [How to digest the filename](#how-to-digest-the-filename)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->


## Quick start

First, you'll need to configure Saviour to indicate what type of storage you'll want to use. For example,
to use local storage:

```ruby
# config/initializers/saviour.rb

Saviour::Config.storage = Saviour::LocalStorage.new(
  local_prefix: Rails.root.join('public/system/uploads/'),
  public_url_prefix: "https://mywebsite.com/system/"
)
```

A local storage will persist the files on the server running the ruby code and will require settings to
indicate precisely where to store those files locally and how to build a public url to them. Those settings
depend on your server and deployment configurations. Saviour ships with local storage and Amazon's S3 storage
capabilities, see the section on [Storages](#storages) for more details.

Saviour will also require a text column for each attachment in an ActiveRecord model. This column will be used to
persist a file's "path" across the storage. For example:

```ruby
create_table "users" do |t|
  # other columns...
  t.text "avatar"
end
```

Then include the mixin `Saviour::Model` in your AR model and declare the attachment:

```ruby
class User < ApplicationRecord
  include Saviour::Model

  attach_file(:avatar) do
    store_dir { "uploads/avatars/#{model.id}/" }
  end
end
```

Declaring a `store_dir` is mandatory and indicates at what base path the assigned files must be stored. More
on this later at the [Uploaders section](#uploader-classes).

Now you can use it:

```ruby
user = User.create! avatar: File.open("/path/to/cowboy.jpg")
user.avatar.read # => binary contents

# Url generation depends on how the storage is configured
user.avatar.url # => "https://mywebsite.com/system/uploads/avatars/1/cowboy.jpg"

# Using local storage, the persisted column will have the path to the file
user[:avatar] # => "uploads/avatars/1/cowboy.jpg"
```


### General Usage

You can assign to an attachment any object that responds to `read`. This includes `File`, `StringIO` and many others.

The filename given to the file will be obtained by following this process:

- First, trying to call `original_filename` on the given object.
- Second, trying to call `filename` on the given object.
- Finally, if that object responds to `path`, it will be extracted as the basename of that path.

If none of that works, a random filename will be assigned.

The actual storing of the file and any possible related processing (more on this [later](#processors)) will 
happen on after save, not on assignation. You can assign and re-assign different values to an attachment at no
cost.


#### Api on attachment

Given the previous example of a User with an avatar attachment, the following methods are available to you on the attachment object:

- `user.avatar.present?` && `.blank?`: Indicates if the attachment has an associated file or not, even if it has not been persisted yet. This methods allow you for a transparent use of rails `validates_presence_of :avatar`, as the object responds to `blank?`.
- `user.avatar.persisted?`: Indicates if the attachment has an associated file and this file is persisted. Is false after assignation and before save.
- `user.avatar?`: Same as `user.avatar.present?`
- `user.avatar.exists?`: If the attachment is `persisted?`, it checks with the storage to verify the existence of the associated path. Use it to check for situations where the database has a persisted path but the storage may not have the file, due to any other reasons (direct manipulation by other means).
- `user.avatar.with_copy {|f| ... }`: Utility method that fetches the file and gives it to you in the form of a `Tempfile`. Will forward the return value of your block. The tempfile will be cleaned up on block termination.
- `user.avatar.read`: Returns binary raw contents of the stored file.
- `user.avatar.url`: Returns the url to the stored file, based on the storage configurations.
- `user.avatar.reload`: If the contents of the storage were directly manipulated, you can use this method to force a reload of the attachment state from the storage.
- `user.avatar.filename`: Returns the filename of the stored file.
- `user.avatar.persisted_path`: If persisted, returns the path of the file as stored in the storage, otherwise nil. It's the same as the db column value.
- `user.avatar.changed?`: Returns true/false if the attachment has been assigned but not yet saved.
 
Usage example:

```ruby
user = User.new

user.avatar? # => false
user.avatar.present? # => false
user.avatar.blank? # => true

user.avatar.read # => nil, same for #url, #filename, #persisted_path

user.avatar = File.open("image.jpg")

user.avatar.changed? # => true
user.avatar? # => true, same as #present?
user.avatar.persisted? # => false

user.avatar.url # => nil, not yet persisted
user.avatar.exists? # => false, not yet persisted
user.avatar.filename # => "image.jpg"
user.avatar.read # => nil, not yet persisted

user.avatar.with_copy # => nil, not yet persisted

user.save!

user.avatar.changed? # => false
user.avatar? # => true
user.avatar.exists? # => true
user.avatar.persisted? # => true

user.avatar.read # => bytecontents
user.avatar.url # => "https://somedomain.com/path/image.jpg"
user.avatar.with_copy # => yields a tempfile with the image
user.avatar.read # => bytecontents
```

 
#### Additional api on the model

When you declare an attachment in an AR model, the model is extended with:

- `#dup`: The `dup` method over the AR instance will also take care of dupping any possible attachment with associated files if any. If the new instance returned by dup is saved, the attachments will be saved as well normally, generating a copy of the files present on the original instance.

- `#remove_<attached_as>!`: This new method will be added for each attachment. For example, `user.remove_avatar!`. Use this method to remove the associated file.

Usage example:

```ruby
user = User.create! avatar: File.open("image.jpg")

user.avatar.url # => "https://somedomain.com/uploads_path/users/1/avatar/image.jpg"

new_user = user.dup
new_user.save!

new_user.avatar.url # => "https://somedomain.com/uploads_path/users/2/avatar/image.jpg"

new_user.remove_avatar!
new_user.avatar? # => false
```



### Storages

Storages are the Saviour's components responsible for file persistence. Local storage and Amazon's S3 storage
are available by default, but more can be built, as they are designed as independent components and any class
that follows the expected public api can be used as one. More on this on the [Custom storage section](custom-storages).

We'll review now how to use the two provided storages.

#### Local Storage

You can use this storage to store files in the local machine running the ruby code. Example:

```ruby
# config/initializers/saviour.rb

Saviour::Config.storage = Saviour::LocalStorage.new(
  local_prefix: Rails.root.join('public/system/uploads/'),
  public_url_prefix: "http://mydomain.com/uploads"
)
```

The `local_prefix` is the base prefix under which the storage will store files in the
machine. You need to configure this accordingly to your use case and deployment strategies, for example, for rails
and capistrano with default settings you'll have to store the files under `Rails.root.join("public/system")`,
as this is by default the shared directory between deployments.

The `public_url_prefix` is the base prefix to build the public endpoint from which you'll serve the assets.
Same as before, you'll need to configure this accordingly to your deployment specifics.

You can also assign a Proc instead of a String to dynamically calculate the value, useful when you have multiple
asset hosts:

`public_url_prefix: -> { https://media-#{rand(4)}.mywebsite.com/system/uploads/" }`

This storage will take care of removing folders after they become empty.

The optional extra argument `permissions` will allow you to set what permissions the files should have locally.
This value defaults to '0644' and can be changed when creating the storage instance:

```ruby
Saviour::Config.storage = Saviour::LocalStorage.new(
  local_prefix: Rails.root.join('public/system/uploads/'),
  public_url_prefix: "http://mydomain.com/uploads",
  permissions: '0600'
)
```

#### S3 Storage

This storage will store files on Amazon S3, using the `aws-sdk-s3` gem. Example:

```ruby
Saviour::Config.storage = Saviour::S3Storage.new(
  bucket: "my-bucket-name",
  aws_access_key_id: "stub",
  aws_secret_access_key: "stub",
  region: "my-region",
  public_url_prefix: "https://s3-eu-west-1.amazonaws.com/my-bucket/"
)
```

The first 4 options (`bucket`, `aws_access_key_id`, `aws_secret_access_key` and `region`) are required for the
connection and usage of your s3 bucket.

The `public_url_prefix` is the base prefix to build the public endpoint from which the files are available.
Normally you'll set it as in the example provided, or you can also change it accordingly to any CDN you may be
using.

You can also assign a Proc instead of a String to dynamically calculate the value, which is useful when you have multiple
asset hosts:

`public_url_prefix: -> { https://media-#{rand(4)}.mywebsite.com/system/uploads/" }`

The optional argument `create_options` can be given to establishing extra parameters to use when creating files. For
example you might want to set up a large cache control value so that the files become cacheable:

```ruby
  create_options: {
    cache_control: 'max-age=31536000' # 1 year
  }
```

Those options will be forwarded directly to aws-sdk, you can see the complete reference here:

https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#put_object-instance_method

Currently, there's no support for different create options on a per-file basis. All stored files will be created 
using the same options. If you want a public access on those files, you can make them public with a general
rule at the bucket level or using the `acl` create option:

```ruby
  create_options: {
    acl: 'public-read'
  }
```

NOTE: Be aware that S3 has a limit of 1024 bytes for the keys (paths) used. Trying to store a file with a
larger path will result in a `Saviour::KeyTooLarge` exception.


### Uploader classes

Uploader classes are responsible to make changes to an attachment byte contents or filename, as well as indicating
what base path that file should have.

An uploader class can be provided explicitly, for example:

```ruby
# app/uploaders/post_image_uploader.rb
class PostImageUploader < Saviour::BaseUploader
  store_dir { "uploads/posts/images/#{model.id}/" }
end

# app/models/post.rb
class Post < ApplicationRecord
  include Saviour::Model

  attach_file :image, PostImageUploader
end
```

Or you can also provide a `&block` to the `attach_file` method to declare the uploader class implicitly. This
syntax is usually more convenient if you don't have a lot of code in your uploaders:

```ruby
class Post < ApplicationRecord
  include Saviour::Model
  
  attach_file :image do
    store_dir { "uploads/posts/images/#{model.id}/" }
  end
end
```


#### store_dir

Declaring a `store_dir` is mandatory for each uploader class. It can be provided directly as a block or as a symbol,
in which case it has to match with a method you define on the uploader class.

Its returning value must be a string representing the base path under which the files will be stored.

At runtime the model is available as `model`, and the name of the attachment as `attached_as`. For example:

```ruby
class PostImageUploader < Saviour::BaseUploader
  store_dir { "uploads/posts/images/#{model.id}/" }
  
  # or
  store_dir { "uploads/posts/#{model.id}/#{attached_as}" }
  
  # or more generic
  store_dir { "uploads/#{model.class.name.parameterize}/#{model.id}/#{attached_as}" }
  
  # or with a method
  store_dir :calculate_dir
  
  def calculate_dir
    "uploads/posts/images/#{model.id}/"
  end
end
```

Since attachment processing and storing happens on after save, at the time `store_dir` is called the model
has already been saved, so the database `id` is available.

The user is expected to configure such store_dirs appropriately so that path collisions cannot happen across
the whole application. To that end, the use of `model.id` and `attached_as` as part of
the store dir is a common approach to ensure there will be no collisions. Other options could involve
random token generation.


#### Processors

Processors are methods (or lambdas) that receive the contents of the file being saved and its filename, 
and in turn return file contents and filename. You can use them to change both values, for example:

```ruby
class PostImageUploader < Saviour::BaseUploader
  store_dir { "uploads/posts/#{model.id}/#{attached_as}" }

  process do |contents, filename|
    new_filename = "#{Digest::MD5.hexdigest(contents)}-#{filename}"
    new_contents = Zlib::Deflate.deflate(contents) 
    
    [new_contents, new_filename]
  end
end
```

Here we're compressing the contents with ruby's zlib and adding a checksum to the filename for caching purposes. The returning
value must be always an array of two values, a pair of contents/filename.

If you want to reuse processors and make them more generic with variables, you can also define them as methods
and share them via a ruby module or via inheritance. In this form, you can pass arbitrary arguments.

```ruby
module ProcessorsHelpers
  def resize(contents, filename, width:, height:)
    new_contents = SomeImageManipulationImplementation.new(contents).resize_to(width, height)
     
    [new_contents, filename]
  end
end

class PostImageUploader < Saviour::BaseUploader
  include ProcessorsHelpers
  store_dir { "uploads/posts/#{model.id}/#{attached_as}" }

  process :resize, width: 100, height: 100 
end
```

You may declare as many processors as you want in an uploader class, they will be executed in the same order as
you define them and they will be chained: the output of the first processor will be the input of the second one, etc.

Inside a processor you also have access to the following variables:

- `model`: The model owner of the file being saved.
- `attached_as`: The name of the attachment being processed.
- `store_dir`: The computed value of the store dir this file will have.

When you use `process` to declare processors as seen before, you're given the raw byte contents that were originally
assigned to the attachment. This may be convenient if you have a use case when you generate those contents yourself
or want to manipulate them directly with ruby, but that's normally not the case. Usually, you assign files to
the attachments and modify them via third party binaries (like imagemagick). In that scenario, in order to reduce
memory usage, you can use instead `process_with_file`.

This is essentially the same but instead of raw byte contents you're given a `Tempfile` instance:

```ruby
class PostImageUploader < Saviour::BaseUploader
  store_dir { "uploads/posts/#{model.id}/#{attached_as}" }

  process_with_file do |file, filename|
    `convert -thumbnail 100x100^ #{Shellwords.escape(file.path)}`
    
    [file, filename] 
  end
end
```

*Note that when escaping to the shell you need to check for safety in case there's an injection in the filename.*

You can modify directly the contents of the given file in the filesystem, or you could also delete the given file and
return a new one. If you return a different file instance, you're expected to clean up the one that was given to you.

You can mix `process` with `process_with_file` but you should try to avoid it, as it will be a performance penalty
having to convert between formats.

Also, even if there's just one `process`, the whole contents of the file will be loaded into memory. Avoid that usage 
if you're conservative about memory usage or take care of restricting the allowed file size you can work with on
any file upload you accept across your application.


##### halt_process

`halt_process` is a method you can call from inside a processor in order to abort the processing and storing
of the current file. You can use this to conditionally store a file or not based on runtime decisions.

For example, you may be storing media files that can be audio, video or images, and you want to generate a
thumbnail for videos and images but not for audio files.

```ruby
class ThumbImageUploader < Saviour::BaseUploader
  store_dir { "uploads/thumbs/#{model.id}/#{attached_as}" }

  process_with_file do |file, filename|
    halt_process unless can_generate_thumb?(file)
    `convert -thumbnail 100x100^ #{Shellwords.escape(file.path)}`

    [file, filename]
  end

  def can_generate_thumb?(file)
    # Some mime type checking
  end
end
```


### Versions

Versions is a common and popular feature on other file management libraries, however, they're usually implemented
in a way that makes the "versioned" attachments behave differently than normal attachments. 

Saviour takes another approach: there's no such concept as a "versioned attachment", there're only attachments.
The way this works with Saviour is by making one attachment "follow" another one, so that whatever is assigned on
the main attachment is also assigned automatically to the follower, and when the main attachment is deleted
also is the follower.

For example:

```ruby
class Post < ApplicationRecord
  include Saviour::Model

  attach_file :image do
    store_dir { "uploads/posts/images/#{model.id}/" }
  end

  attach_file :image_thumb, follow: :image, dependent: :destroy do
    store_dir { "uploads/posts/image_thumbs/#{model.id}/" }
    process_with_file :resize, width: 100, height: 100
  end
end
```

Using the `follow: :image` syntax you declare that the `image_thumb` attachment has to be automatically assigned 
to the same contents as `image` every time `image` is assigned. 

The `:dependent` part is mandatory and indicates if the `image_thumb` attachment has to be removed when the
`image` is removed (with `dependent: :destroy`) or not (with `dependent: :ignore`).

```ruby
a = Post.create! image: File.open("/path/image.png")
a.image # => original file assigned
a.image_thumb # => a thumb over the image assigned
```

Now, both attachments are independent:

```ruby
# `image_thumb` can be changed independently
a.update_attributes! image_thumb: File.open("/path/another_file.png")

# or removed
a.remove_file_thumb!
```

If `dependent: :destroy` has been choosed, then removing `image` will remove `image_thumb` as well:

```ruby
a.remove_image!
a.image? # => false
a.image_thumb? # => false
````

If the "versioned attachment" is assigned at the same time as the main one, the provided files will be preserved:

```ruby
a = Post.create! image: File.open("/path/image.png"), image_thumb: File.open("/path/thumb.jpg")
a.image # => 'image.png' file
a.image_thumb # => 'thumb.jpg' file

# The same happens when assignations and db saving are separated:

a = Post.find(42)

# other code ...
a.image_thumb = File.open("/path/thumb.jpg")

# other code ...
a.image = File.open("/path/image.png")

# other code ...
a.save!
a.image # => 'image.png' file
a.image_thumb # => 'thumb.jpg' file
```

Finally, even if you selected to use `dependent: :destroy` you may choose to not remove the "versions" when
removing the main attachment using an extra argument when removing:

```ruby
a = Post.create! image: File.open("/path/image.png")
a.remove_image!(dependent: :ignore)
a.image? # => false
a.image_thumb? # => true
```

The same is true for the opposite, you could use `remove_image!(dependent: :destroy)` if the attachment was
configured as `dependent: :ignore`.


### Transactional behavior

When working with attachments inside a database transaction (using Active Record), all the changes made will be
reverted if the transaction is rolled back.

On file creation (either creating a new AR model or assigning a file for the first time), the file will be
available on after save, but will be removed on after rollback.

On file update, changes will be available on after save, but the original file will be restored on after rollback.

On file deletion, the file will be no longer available (via Saviour public api) on after save, but the actual deletion
will happen on after commit (so in case of rollback the file is never removed).


### Concurrency

Saviour will run all processors and storage operations concurrently for all attachments present in a model. For example:

```ruby
class Product < ApplicationRecord
  include Saviour::Model

  attach_file :image, SomeUploader
  attach_file :image_thumb, SomeUploader, follow: :image
  attach_file :cover, SomeUploader
end

a = Product.new image: File.open('...'), cover: File.open('...')
a.save!
```

At the time that `save!` is executed, 3 threads will be opened. In each one, the processors you defined will be
executed for that file, and then the result will be written to the storage.

In case you have so many attachments that processing them concurrently would be undesired you can limit the
max concurrency with:

```ruby
Saviour::Config.concurrent_workers = 2
```

The default value is 4.


#### stash

Note that this means **your processor's code must be thread-safe**. Do not issue db queries from processors
directly, for example. They would be executed in a new connection by AR and you may not be expecting that.

Saviour comes with a simple mechanism to gather data from processors so that you can use it later from
the main thread: `stash`. For example:


```ruby
class ImageUploader < Saviour::BaseUploader
  store_dir { "uploads/thumbs/#{model.id}/#{attached_as}" }

  process_with_file do |file, filename|
    width, height = `identify -format "%wx%h" #{Shellwords.escape(file.path)}`.strip.split(/x/).map(&:to_i)

    stash(
      width: width,
      height: height,
      size: File.size(file.path)
    )

    [file, filename]
  end

  after_upload do |stash|
    model.update_attributes!(size: stash[:size], width: stash[:width], height: stash[:height])
  end
end
```

Use `stash(hash)` to push a hash of data from a processor. You can call this multiple times from different processors,
the hashes you stash will be deep merged. You can then declare an `after_upload` block that will run in the main
thread once all attachments have been saved to the storage. The block will simply receive the stash hash, and from
there you can run arbitrary code to persist the info.


### Dirty tracking

Saviour implements dirty tracking for the attachments. Given the following example:

```ruby
class User < ApplicationRecord
  include Saviour::Model

  attach_file(:avatar) do
    store_dir { "uploads/avatars/#{model.id}/" }
  end
end
```

You can now use:

```ruby
a = User.create! avatar: File.open("avatar.jpg")

a.avatar = File.open("avatar_2.jpg")

a.changed? # => true

a.avatar_changed? # => true

a.avatar_was.url # => url pointing to the original avatar.jpg file
a.avatar_was.read # => previous byte contents

a.changed_attributes # => { avatar: <Saviour::File instance of avatar.jpg>}
a.avatar_change # => [<Saviour::File instance of avatar.jpg>, <Saviour::File instance of avatar_2.jpg>]
a.changes # => { avatar: [<Saviour::File instance of avatar.jpg>, <Saviour::File instance of avatar_2.jpg>] }

a.save!

a.avatar_changed? # => false
```



### AR Validations

You can use `attach_validation` in an Active Record model to declare validations over attachments, for example:

```ruby
class User < ApplicationRecord
  include Saviour::Model

  attach_file(:avatar) do
    store_dir { "uploads/avatars/#{model.id}/" }
  end

  attach_validation :avatar do |contents, filename|
    errors.add(:avatar, "max 10 Mb") if contents.bytesize > 10.megabytes
    errors.add(:avatar, "invalid format") unless %w(jpg jpeg).include?(File.extname(filename))
  end
end
```

Similar as with processors, your block will receive the raw byte contents of the assigned file (or object) and the
filename. Adding errors is up to the logic you want to have.

Validations can also be expressed as methods in the model:

```ruby
class User < ApplicationRecord
  include Saviour::Model

  attach_file(:avatar) do
    store_dir { "uploads/avatars/#{model.id}/" }
  end

  attach_validation :avatar, :check_format

  def check_format(contents, filename)
    errors.add(:avatar, "invalid format") unless %w(jpg jpeg).include?(File.extname(filename))
  end
end
```

In both forms (block or method) an additional 3rd argument will be provided as a hash of `{attached_as: "avatar"}`
in this example. You can use this to apply different logic per attachment in case of shared validations.

Those validations will run on before save, so none of the processors you may have defined did run yet. The contents
and filename provided in the validation are the ones originally assigned to the attachment.

You can also use the variation `attach_validation_with_file`, which is the same but instead of raw contents you're
given a `File` object to work with. Use this to preserve memory if that's your use case, same considerations apply
as in the processor's case.


### Introspection

Two methods are added to any class including `Saviour::Model` to give you information about what attachments
have been defined in that class.

`Model.attached_files` will give an array of symbols, representing all the attachments declared in that class.

`Model.attached_followers_per_leader` will give a hash where the keys are attachments that have versions
assigned, and the values being an array of symbols, representing the attachments that are following that attachment.

```ruby
class Post < ApplicationRecord
  include Saviour::Model

  attach_file :image, SomeUploader
  attach_file :image_thumb, SomeUploader, follow: :image, dependent: :destroy
  attach_file :image_thumb_2, SomeUploader, follow: :image, dependent: :destroy
  attach_file :cover, SomeUploader
end

Post.attached_files # => [:image, :image_thumb, :image_thumb_2, :cover]
Post.attached_followers_per_leader # => { image: [:image_thumb, :image_thumb_2] }
```


## Extras & Advance usage

### Skip processors

Saviour has a configuration flag called `processing_enabled` that controls whether or not to execute processors.
You can set it:

`Saviour::Config.processing_enabled = false`

It's thread-safe and can be changed on the fly. Use it if you, for some reason, need to skip processing in a general
way.

### Testing

As file management is an expensive operation if you're working with a remote storage like s3, there
are some things that you might want to change during test execution.

First of all, you can use a local storage on tests instead of s3, only this will speed up your suite a lot.
If you have some tests that must run against s3, you can use an s3 spec flag to conditionally
swap storages on the fly:

```ruby
# config/env/test.rb
Saviour::Config.storage = ::LocalStorage.new(...) 

# spec/support/saviour.rb
module S3Stub
  mattr_accessor :storage
  
  self.storage = Saviour::S3Storage.new(...)
end

RSpec.configure do |config|
  config.around(:example, s3_storage: true) do |example|
    previous_storage = Saviour::Config.storage
    Saviour::Config.storage = S3Stub.storage

    example.call

    Saviour::Config.storage = previous_storage
  end
end

it "some regular test" do 
  # local storage here
end

it "some test with s3", s3_storage: true do
  # s3 storage here
end
```

Finally, you can also choose to disable execution of all processors during tests:

```ruby
# spec/support/saviour.rb

Saviour::Config.processing_enabled = false
```

This will skip all processors, so you'll avoid image manipulations, etc. If you have a more complex application
and you can't disable all processors, but still would want to skip only the ones related to image manipulation, 
I would recommend to delegate image manipulation to a specialized class and then stub all of their methods. 
 

### Sources: url and string

Saviour comes with two small utility classes to encapsulate values to assign as attachments.

If you want to provide directly the contents and filename, you can use `Saviour::StringSource`:

`Post.create! image: Saviour::StringSource.new("hello world", "file.txt")`

If you want to assign a file stored in an http endpoint, you can use `Saviour::UrlSource`:

`Post.create! image: Saviour::UrlSource.new("https://dummyimage.com/600x400/000/fff")`


### Custom Storages

An storage is a class that implements the public api expected by Saviour. The abstraction expected
by Saviour is that, whatever the underlying platform or technology, the storage is able to persist
the given file using the given path as a unique identifier.

The complete public api that must be satisfied is:

- write(raw_contents, path): Given raw byte contents and a full path, the storage is expected to
persist those contents indexed by the given path, so that later on can be retrieved by the same path.
The return value is ignored.

- read(path): Returns the raw contents stored in the given path.

- write_from_file(file, path): Same as write, but providing a file object rather than raw contents. The storage
has the opportunity to implement this operation in a more performant way, if possible (local storage does here
a `cp`, for example). The return value is ignored.

- read_to_file(path, file): Same as read, but writing to the given file directly instead of returning raw values.
The storage has the opportunity to implement this operation in a more performant way, if possible.
The return value is ignored.

- delete(path): Removes the file stored at the given path. The return value is ignored.

- exists?(path): Returns a boolean true/false, depending if the given path is present in the storage or not.
S3 storage implements this with a HEAD request, for example.

- public_url(path): Returns a string corresponding to an URL under which the file represented by the given
path is available.

- cp(source_path, destination_path): Copies the file from "source_path" into "destination_path". Overwrites
"destination_path" if necessary.

- mv(source_path, destination_path): Moves the file from "source_path" into "destination_path". Overwrites
"destination_path" if necessary, and removes the file at "source_path".

`cp` and `mv` are explicitly created in order to give a chance to the storage to implement the feature in a more
performant way, for example, s3 implements `cp` as direct copy inside s3 without downloading/uploading the file.

If the given path does not correspond with an existing file, in the case of `read`, `read_to_file`, `delete`, `cp` or
`mv`, the storage is expected to raise the `Saviour::FileNotPresent` exception.

Any additional information the storage may require can be provided on instance creation (on `initialize`) since
this is not used by Saviour.


### Bypassing Saviour

The only reference to stored files Saviour holds and uses is the path persisted in the database. If you want to,
you can directly manipulate the storage contents and the database in any custom way and Saviour will just pick
the changes and work from there.

Since Saviour is by design model-based, there may be use cases when this becomes a performance issue, for example:

##### Bypass example: Nested Cloning 

Say that you have a model `Post` that has many `Image`s, and you're working with S3. `Post` has 3 attachments and 
`Image` has 2 attachments. If you want to do a feature to "clone" a post, a simple implementation would be to 
basically `dup` the instances and save them.

However, for a post with many related images, this would represent many api calls and roundtrips to download
contents and re-upload them. It would be a lot faster to work with s3 directly, issue api calls to copy the
files inside s3 directly (no download/upload, and even you could issue those api calls concurrently), 
and then assign manually crafted paths directly to the new instances.


## FAQ

### how to reuse code in your app, attachment with defaults

If your application manages many file attachments and you want certain things to apply to all of them, you can
extract common behaviors into a module:

```ruby
module FileAttachmentHelpers
  # Shared processors 
end

module FileAttachment
  extend ActiveSupport::Concern

  included do
    include Saviour::Model
  end

  class_methods do
    def attach_file_with_defaults(*args, &block)
      attached_as = args[0]

      attach_file(*args) do
        include FileAttachmentHelpers

        store_dir { "uploads/#{model.class.name.parameterize}/#{model.id}/#{attached_as}" }

        instance_eval(&block) if block
        process_with_file :sanitize_filename
        process_with_file :digest_filename
        process_with_file :truncate_at_max_key_size
      end

      attach_validation_with_file(attached_as) do |file, _|
        errors.add(attached_as, 'is an empty file') if ::File.size(file.path).zero?
      end
    end

    def validate_extension(*validated_attachments, as:)
      formats = Array.wrap(as).map(&:to_s)

      validated_attachments.each do |attached_as|
        attach_validation_with_file(attached_as) do |_, filename|
          ext = ::File.extname(filename)
          unless formats.include?(ext.downcase.delete('.'))
            errors.add(attached_as, "must have any of the following extensions: '#{formats}'")
          end
        end
      end
    end
  end
end

class Post < ApplicationRecord
  include FileAttachment
  
  attach_file_with_defaults :cover # Nothing extra needed
  
  attach_file_with_defaults :image do
    process_with_file :some_extra_thing
  end
end
```

In this example we're encapsulating many behaviors that will be given for free to any declared attachments:

- `store_dir` computed by default into a path that will be different for each class / id / attached_as.
- 3 generic processors are always run, `sanitize_filename` to ensure we'll have a sane url in the end, `digest_filename` to append a digest and `truncate_at_max_key_size` to ensure we don't reach the 1024 bytes imposed by S3.
- All attachments will validate that the assigned file must not be empty (0 bytes file).
- An utility method is added to allow for validations against the filename extension with `validate_extension :image, as: %w[jpg jpeg png]`


### How to manage file removal from forms

This feature can be implemented with a temporal flag in the model, which is exposed in the forms and passed via
controllers, and a `before_update` to read the value and delete the attachment if present. For example, the
`FileAttachment` module exposed in the previous point could be extended as such:

```ruby
module FileAttachment
  # ...
  class_methods do
    def attach_file_with_defaults(*args, &block)
      attached_as = args[0]
      # ...
    
      define_method("remove_#{attached_as}") do
        instance_variable_get("@remove_#{attached_as}")
      end

      alias_method "remove_#{attached_as}?", "remove_#{attached_as}"

      define_method("remove_#{attached_as}=") do |value|
        instance_variable_set "@remove_#{attached_as}", ActiveRecord::Type::Boolean.new.cast(value)
      end
      
      before_update do
        send("remove_#{attached_as}!") if send("remove_#{attached_as}?")
      end
    end
  end
end
```

Then it can be used as:

```ruby
# This would be a controller code
a = Post.find(42)

# Params received from a form
a.update_attributes(remove_image: "t")
```


### How to extract metadata from files

You can use processors to accomplish this. Just be aware that processors run concurrently, so if you want to 
persist you extracted information in the database probably you'll want to use `stash`, see [the section
about stash feature for examples](#stash).


### How to process files in background / delayed

As a previous warning note, pushing logic to be run in the background, when they have visible consequences for the application, may
have undesired side effects and added complexity. For example, as you can't be sure about when the delayed job
will be completed, your application now needs to handle the uncertainty about the situation: The file processing may
or may not have run yet.

Implementing a delayed processor means that Saviour is no longer involved in the process. You could add the
enqueuing of the job when you detect a change in the attachment:

```ruby
class Post < ApplicationRecord
  include Saviour::Model
  attach_file :image
  
  before_save do 
    if image_changed?
      # On after commit, enqueue the job
    end
  end
end
```

The job then should take the model and the attachment to process and run the processings directly:

```ruby
a = Post.find(42)
a.image.with_copy do |f|
  # manipulate f as desired
  a.update_attributes! image: f 
end
```


### How to recreate versions

As "versions" are just regular attachments, you only need to assign to it the contents of the main attachment. You can
also directly assign attachments between themselves. For example:

```ruby
class Post < ApplicationRecord
  include Saviour::Model

  attach_file :image, SomeUploader
  attach_file :image_thumb, SomeUploader, follow: :image, dependent: :destroy
end

post = Post.find 42
post.image_thumb = post.image
post.save!
```

### How to digest the filename

You can use a processor like this one:

```ruby
  def digest_filename(file, filename, opts = {})
    separator = opts.fetch(:separator, '-')

    digest = ::Digest::MD5.file(file.path).hexdigest
    extension = ::File.extname(filename)

    previous_filename = ::File.basename(filename, '.*')

    if Regexp.new("[0-9a-f]{32}#{Regexp.escape(extension)}$").match(filename)
      # Remove the previous digest if found
      previous_filename = previous_filename.split(separator)[0...-1].join(separator)
    end

    new_filename = "#{previous_filename}#{separator}#{digest}#{extension}"

    [file, new_filename]
  end
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

