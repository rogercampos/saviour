ActiveRecord::Schema.define do
  create_table :tests do |t|
    t.string :file
    t.string :file_thumb
    t.string :file_thumb_2
    t.string :file_thumb_3
    t.string :name
    t.integer :file_size
    t.integer :size_file
    t.integer :size_file_thumb
    t.timestamps null: false
  end

  create_table :test_no_timestamps do |t|
    t.string :file
    t.string :name
  end
end
