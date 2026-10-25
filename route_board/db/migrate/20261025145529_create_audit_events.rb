class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.string :actor_role
      t.string :action
      t.text :details

      t.timestamps
    end
  end
end
