class RenameChangesToPayloadInAuditEvents < ActiveRecord::Migration[8.1]
  def change
    rename_column :audit_events, :changes, :payload
  end
end