# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 20_260_101_000_005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension 'pg_catalog.plpgsql'

  create_table 'chronicle_admin_users', force: :cascade do |t|
    t.string 'auth_token', null: false
    t.datetime 'created_at', null: false
    t.string 'email', null: false
    t.string 'name', null: false
    t.string 'password_digest', null: false
    t.integer 'role', default: 0, null: false
    t.datetime 'updated_at', null: false
    t.index ['auth_token'], name: 'index_chronicle_admin_users_on_auth_token', unique: true
    t.index ['email'], name: 'index_chronicle_admin_users_on_email', unique: true
  end

  create_table 'chronicle_api_logs', force: :cascade do |t|
    t.string 'api_endpoint'
    t.string 'backend_version'
    t.string 'brand'
    t.string 'client_version'
    t.datetime 'created_at', null: false
    t.string 'device_id'
    t.string 'device_model_name'
    t.string 'device_os'
    t.string 'device_type'
    t.integer 'frontend_response_time_ms'
    t.string 'http_method'
    t.integer 'http_status_code'
    t.string 'ip_address'
    t.json 'meta'
    t.string 'os_version'
    t.json 'path_params'
    t.string 'request_id'
    t.integer 'response_time_ms'
    t.string 'time_zone'
    t.datetime 'timestamp'
    t.datetime 'updated_at', null: false
    t.bigint 'user_id'
    t.index ['request_id'], name: 'index_chronicle_api_logs_on_request_id'
    t.index ['timestamp'], name: 'index_chronicle_api_logs_on_timestamp'
    t.index ['user_id'], name: 'index_chronicle_api_logs_on_user_id'
  end

  create_table 'chronicle_api_routes', force: :cascade do |t|
    t.datetime 'created_at', null: false
    t.datetime 'first_seen_at', null: false
    t.string 'http_method', null: false
    t.string 'path', null: false
    t.datetime 'updated_at', null: false
    t.index %w[path http_method], name: 'index_chronicle_api_routes_on_path_and_method', unique: true
  end

  create_table 'chronicle_error_groups', force: :cascade do |t|
    t.string 'backend_version'
    t.text 'cleaned_backtrace'
    t.string 'client_version'
    t.datetime 'created_at', null: false
    t.string 'error_message', null: false
    t.string 'fingerprint', null: false
    t.datetime 'first_seen_at', null: false
    t.string 'jira_link'
    t.datetime 'last_seen_at', null: false
    t.integer 'occurrence_count', default: 0, null: false
    t.text 'original_backtrace'
    t.string 'project', null: false
    t.string 'source_name', null: false
    t.string 'source_type', null: false
    t.string 'status', default: 'open', null: false
    t.datetime 'updated_at', null: false
    t.index ['last_seen_at'], name: 'index_chronicle_error_groups_on_last_seen_at'
    t.index %w[project fingerprint], name: 'index_chronicle_error_groups_on_project_and_fingerprint', unique: true
    t.index ['status'], name: 'index_chronicle_error_groups_on_status'
  end

  create_table 'chronicle_error_logs', force: :cascade do |t|
    t.string 'backend_version'
    t.string 'client_version'
    t.json 'context'
    t.datetime 'created_at', null: false
    t.bigint 'error_group_id', null: false
    t.string 'request_id'
    t.datetime 'updated_at', null: false
    t.bigint 'user_id'
    t.index ['error_group_id'], name: 'index_chronicle_error_logs_on_error_group_id'
    t.index ['user_id'], name: 'index_chronicle_error_logs_on_user_id'
  end

  add_foreign_key 'chronicle_error_logs', 'chronicle_error_groups', column: 'error_group_id'
end
