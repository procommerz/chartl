class CreateChartl < ActiveRecord::Migration
  def change
    create_table :chartl_charts do |t|
      t.integer :user_id, index: true
      t.string :name
      t.string :token, index: true
      t.text :data_code
      t.text :description
      t.datetime :to_time
      t.datetime :from_time
      t.integer :longest_series_size
      t.jsonb :series
      t.jsonb :options

      t.timestamps
    end
  end
end
