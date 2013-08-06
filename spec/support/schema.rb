ActiveRecord::Schema.define do
  create_table :tests do |t|
    t.string :file
    t.string :name
    t.timestamps
  end
end
