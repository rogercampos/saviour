ActiveRecord::Schema.define do
  create_table :tests do |t|
    t.string :file
    t.string :file_thumb
    t.string :file_thumb_2
    t.string :name
    t.timestamps null: false
  end
end