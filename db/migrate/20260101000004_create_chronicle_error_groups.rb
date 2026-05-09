class CreateChronicleErrorGroups < ActiveRecord::Migration[7.1]
  def change
    create_table :chronicle_error_groups do |t|
      t.string  :project,            null: false
      t.string  :fingerprint,        null: false
      t.string  :source_type,        null: false
      t.string  :source_name,        null: false
      t.string  :error_message,      null: false
      t.text    :original_backtrace
      t.text    :cleaned_backtrace
      t.string  :status,             null: false, default: 'open'
      t.integer :occurrence_count,   null: false, default: 0
      t.string  :jira_link
      t.string  :backend_version
      t.string  :client_version
      t.datetime :first_seen_at,     null: false
      t.datetime :last_seen_at,      null: false

      t.timestamps
    end

    add_index :chronicle_error_groups, [:project, :fingerprint], unique: true, name: 'index_chronicle_error_groups_on_project_and_fingerprint'
    add_index :chronicle_error_groups, :status
    add_index :chronicle_error_groups, :last_seen_at
  end
end
