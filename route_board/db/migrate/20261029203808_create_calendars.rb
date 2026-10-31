class CreateCalendars < ActiveRecord::Migration[8.1]
  def change
    create_table :calendars, primary_key: :service_id, id: :string do |t|
      t.boolean :monday,    default: false
      t.boolean :tuesday,   default: false
      t.boolean :wednesday, default: false
      t.boolean :thursday,  default: false
      t.boolean :friday,    default: false
      t.boolean :saturday,  default: false
      t.boolean :sunday,    default: false
      t.date    :start_date
      t.date    :end_date
    end
  end
end