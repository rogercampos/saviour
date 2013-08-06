- One uploader per file

- Versions are handled with other uploaders, each one must have its own
  column.

- Plays well with AR lifecycle.
  - On assignation an object is instantiated representing the given
    file. No processing code is executed (very lightweight).
  - `before_save` the file is uploaded to s3
  - `after_destroy` the file is removed from s3
  - `before_validation` the metadata is filled, and possible file
    renamings happens now
  - `before_save` processings to change the file and generate versions are run

- Exposes an api to download the file, operate with it and remove it
  after executing the block.

- The required column is a string column which stores the full file path
  on s3.

- Metadata is calculated on the fly on `before_validation` and must be
  preserved by the user if desired.

- `#file` gives you an instance of a subclass of `Saviour::File`. This object
  can be `persisted?` or not, depending if you called `save` or not on your model.

- `#file=` assigns a `File` instance into the mounter. Saviour only remembers the
  fd you provided and that's what will be used `on save`. Then the fd is `read`ed
  and the contents used to create the new file. Note that you may change that fd or
  whatever before calling `save` on the model, Saviour will still persist whatever
  is available at that fd when the model is saved.

1.0: Storing files
1.1: remote_url assignation
1.2: metadata processing: mime type, file size, extension, etc.
1.3: Processing hooks
1.4: Digest module, append digest to filename


-----------

- Proposal alternate syntax:

class Test < ActiveRecord::Base
  attach_file(:thumb_image, store_dir: "") do
    run :resize_to_fit, width: 100, height: 100
  end
end

-----------


- You can assign anything that responds to a `read` method in order to retrieve the contents.
  Optionally, if the object responds to `path` that will be used also to construct the filename based on
  `File.basename(object.path)`
  If not you will need to set the `filename` directly before trying to `write`.


# API:

```
class Product
  attach_file :image, BaseUploader
end

a = Product.new image: File.open('/home/user/file.jpg')
a.image # => <Saviour::File>

a.image.filename
a.image.extension

a.


```

# Example: AR model named attachment:

a = Attachment.new
a.file = File.open('/home/patata/asd.jpg')

# In this moment `a.file` is an instance of Saviour::File which is not `persisted?`.

a.file.persisted? #=> false
a.file.read #=> Saviour::RuntimeError 'the file is not persisted'
a.file.filename #=> Saviour::RuntimeError 'the file is not persisted'

# Calling `write` will trigger the persistence. This automatically occurs on `after_save` the model.
# At this time is when Saviour reads the file and uses the content to create a new file. The filename and extensions are
# the same as in the original filename, altought you may change that before calling `write`.

# In the scneario of assigning an IO object, for example, the filename and extension are blank and trying to `write` before
# assign them will result in an Exception.

a.file.write("/local/path/") # The exact API for `write` depends on the backend. File storage and S3 storage have different apis.
a.file.persisted? #=> true
a.file.filename #=> "file1.jpg"



# Example for IO

a = Attachment.new
a.file = IO.new('/my/socket')

a.write('/local/path/')  #=> Saviour::NoNameError, You will need to provide a filename and extension before trying to save a file
                          # comming from an IO.

# The behaviour about when the file ends when reading from stream is the same as `read` from ruby for IO. Firs EOF will be
considered as termination. For further customization deal with the stream yourself and assign a File instead.



# Example for an external URL using the UrlWrapper provided by Saviour. This is only an utility class that complains with the
# previous specification. You can use whatever you want however, as long as it responds to `read` and optionally `path`.

a = Attachment.new
a.file = Saviour::UrlWrapper.new('http://server.com/file.jpg')

a.file.persisted? #=> false

a.write #=> true, Saviour downloads and assigns the file, using the filename extracted from the URL.


-----------------------------

# Saviour::File logic:

- handles the api side of saviour, what shall we show the user based on the current state. Handle interactions.
- handles logic of what can be assigned and how it's treated (`read` and `path`).
- handles AR cycle, when the file will be persisted into the storage and with what filename.
- decides when to upload. dirty checking.
- implement url method (what should be exposed to the user instead of the raw storage path). this is optional!!


# Saviour::Uploader logic:

manages how to upload a thing to the storage. what content, path and filename. manages hooks and preprocessing.
Only acts when something has to be saved into the storage. Has nothing to do with retrieving the file, reading or
deleting from the storage.

- sets the store path
- processing and hooks
  * define a stack of "things" to run. Same architecture as "rack" and middlewares.
  * each layer can modify the contents or the filename, and the later layer will see the modified values.
  * change the filename
  * change the contents
  * run additional code without modifying anything, but to get information (file size, meta, etc.)


# Saviour::Storage logic:

- Implement the following operations in an specific storage

- `write`: writes a given file into the storage
- `read`: read the contents of a file given its path
- `exists?`: check existance of a file given its path
- `delete`: remove a file from the storage given its path


----

PENDING:

- generation of the URL for both storages
- how processors work and how do we call them. Based on content + filename ? What about a fd? Performance?
- What is a file? Just contents + filename, or shall we extract it to add permissions for example?
- What about specific stuff per storage. For example s3 has some ACL for each file stored.
- integration with "mini magick kind" of processors
- Proposal for managing different storages: use theglobal one that can be overrided on the `attach_file` syntax, like
  attach_file :image, MyUploader, storage: MyStorage.new

  You can provide an object directly or also a Proc, in which case will have a dynamic storage! (we `call` it every time)