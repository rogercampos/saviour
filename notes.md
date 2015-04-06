- One uploader per file

- Versions are handled with other uploaders, each one must have its own
  column.

- Plays well with AR lifecycle.
  - On assignation an object is instantiated representing the given
    file. No processing code is executed.
  - `after_save` the file is persisted. If there was a previous file stored, that's removed first.
  - `after_destroy` the file is removed

- Exposes an api to download the file, operate with it and remove it
  after executing the block.

- The required column is a string column which stores the full file path.


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

a.



-----------------------------

# Saviour::File logic:

- handles the api side of saviour, what shall we show the user based on the current state. Handle interactions.
- handles logic of what can be assigned and how it's treated (`read` and `path`).
- handles AR cycle, when the file will be persisted into the storage and with what filename.
- decides when to upload. dirty checking.
- implement url method (what should be exposed to the user instead of the raw storage path). this is optional!!


# Saviour::Uploader logic:

It's initialized with whatever data you want to have accessible from the inside. It's only public method is `write(content, filename)`,
which you can use to upload the given contents as the given filename using the current `Saviour.storage` backend.
It manages what additional stuff happens during the upload to the storage, apart from setting the directory. What content,
path and filename. manages hooks and preprocessing. Only acts when something has to be saved into the storage.
Has nothing to do with retrieving the file, reading or deleting from the storage.

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

- how processors work and how do we call them. Based on content + filename ? What about a fd? Performance?
- What is a file? Just contents + filename, or shall we extract it to add permissions for example?
- What about specific stuff per storage. For example s3 has some ACL for each file stored.
- integration with "mini magick kind" of processors
- Proposal for managing different storages: use the global one that can be overrided on the `attach_file` syntax, like
  attach_file :image, MyUploader, storage: MyStorage.new

  You can provide an object directly or also a Proc, in which case will have a dynamic storage! (we `call` it every time)



VERSIONS:

Features:

- When deleting the parent the version is also destroyed
- shared source, assigning on the parent and saving will trigger both processor chains, reading form the source only once
and passing duplicated data to both processors
- "shared" processor definiton with the parent, since the version may be generated from some step within the parent processing. It's easier and avoids repeating.


notes:

- Uploader class: Now when initialized you can pass an additional name representing a version. New api method named
  "version(:name) { }" from within a processor definition, that will make the given block act only if the name
  of the version used to initilaize the uploader matches the given name on the call to derived_version.

  This way the same uploader can work in different way depending on the "version" given (if any).

- attach_file :file, Uploader, versions: [:a, :b]. Now ths method gains a third argument ":versions". You can declare derived versions.
  Those columns must exist in the model. Those will operate exactly the same way form the exterior. Only two new features:

  1) Auto remove of the version whe the main file is removed
  2) Auto assignation of the

- By default the filename for the version is the same as the parent + suffix with the version name. Can be modified
using `run` inside the verison and changing the filename to something else.
