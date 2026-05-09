class CreateChronicleApiLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :chronicle_api_logs do |t|
      t.bigint  :user_id
      t.string  :request_id
      t.string  :device_os
      t.string  :device_id
      t.string  :device_type
      t.string  :device_model_name
      t.string  :brand
      t.string  :os_version
      t.string  :time_zone
      t.string  :client_version
      t.string  :backend_version
      t.string  :ip_address
      t.string  :http_method
      t.string  :api_endpoint
      t.integer :http_status_code
      t.integer :response_time_ms
      t.integer :frontend_response_time_ms
      t.datetime :timestamp
      t.json    :path_params
      t.json    :meta

      t.timestamps
    end

    add_index :chronicle_api_logs, :user_id
    add_index :chronicle_api_logs, :request_id
    add_index :chronicle_api_logs, :timestamp
  end
end
