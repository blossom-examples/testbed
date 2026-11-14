class CreateWorkItems < ActiveRecord::Migration[8.1]
  def change
    create_table :work_items do |t|
      t.string :request_key, null: false
      t.integer :duration_ms, null: false, default: 50
      t.integer :effect_count, null: false, default: 0
      t.datetime :completed_at
      t.string :processed_by
      t.timestamps
    end
    add_index :work_items, :request_key, unique: true
  end
end
