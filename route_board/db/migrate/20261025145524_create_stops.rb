class CreateStops < ActiveRecord::Migration[8.1]
  def change
    create_table :stops do |t|
      t.string :name
      t.decimal :latitude
      t.decimal :longitude

      t.timestamps
    end
  end
end
