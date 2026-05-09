class CreateChronicleErrorLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :chronicle_error_logs do |t|
      t.bigint :error_group_id, null: false
      t.bigint :user_id
      t.string :request_id
      t.string :backend_version
      t.string :client_version
      t.json   :context

      t.timestamps
    end

    add_index :chronicle_error_logs, :error_group_id
    add_index :chronicle_error_logs, :user_id

    add_foreign_key :chronicle_error_logs, :chronicle_error_groups, column: :error_group_id
  end
end
