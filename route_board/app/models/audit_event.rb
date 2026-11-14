class AuditEvent < ApplicationRecord
  validates :actor, :action, :subject_type, :subject_id, presence: true
end