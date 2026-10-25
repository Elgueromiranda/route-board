class CreateRoutes < ActiveRecord::Migration[8.1]
  def change
    create_table :routes do |t|
      t.string :name
      t.string :code

      t.timestamps
    end
    add_index :routes, :code, unique: true
  end
end
