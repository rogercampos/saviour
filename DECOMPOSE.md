- New saviour-ar gem will provide what's currently in saviour gem
- saviour gem will be data-storage independent. It will provide a way to manage files with processors, but without a
lifecycle attached to a database-model. It will provide a more low level api.
- saviour-ar will provide the specific integration with active record.


# Saviour agnostic gem API


First, you'll need to define what files can be saved in what objects (any Ruby class). You can do that by including the `Saviour::BasicModel` module, example:

```
class MyObject
  include Saviour::BasicModel

  attach_file :image, ImageUploader
  attach_file :scheme, FileUploader
end
```

Now, you can assign and work with the files associated to instances of MyObject with the following api:

```
# New file

a = MyObject.new
a.image = File.open('/path/image.jpg')
a.image.assign File.open('newfile.jpg')
a.image.changed? # => true
saved_path = a.image.write # => persists file in the storage and returns the path in which the file has been saved

b = MyObject.new
b.image.set_path!(saved_path) # => Link this image to the persisted image from before
b.image.exists? # => true
b.image.read # -> return bytes
b.image.delete # -> delete
b.image.exists? # => false

# ...
```

If you want to work directly managing the files associated to those objects, you can use the `Saviour::File` public API directly.

However, Saviour is designed to work with models that are saved in some kind of persistent storage, like a database of some sort. This is why Saviour also provides a generic `LifeCycle` service which you can use to simulate the persistence lifecycle of the object. You can then use:

```
a = MyObject.new image: File.open('image.jpg')

Saviour::LifeCycle.new(a).save!
Saviour::LifeCycle.new(a).delete!
```

`save!` will have the effect of saving all the attachments associated with the object, and `delete!` will have the effect of removing all the files associated with this object from the file storage defined.

Using LifeCycle you consider the object as a whole, while working with individual files you have more control, but you always operate with individual files.

The feature of versions, for example, only applies when you use the LifeCycle approach, since, by definition, a version is automatically constructed from the original file while this one is saved, and this involved operating in two or more attachments at the same time over an specific object. Since in Saviour versions can be managed exactly like regular attachments, such behavior don't apply when you work with File instances directly.


# Saviour API for developers

If you want to develop a new gem to integrate Saviour with another persistence technology, you need to do two things.

1) Write a class with the api #read, #write and #persisted? and give it to Savior, so he knows how to work with the persistence layer.
2) Write a new module for the final users to include in their models, providing the expected hooks so that the usage of the `LifeCycle` is automatic and transparent.

