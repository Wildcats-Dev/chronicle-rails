class CreateChronicleApiRoutes < ActiveRecord::Migration[7.1]
  def change
    create_table :chronicle_api_routes do |t|
      t.string   :path,        null: false
      t.string   :http_method, null: false
      t.datetime :first_seen_at, null: false

      t.timestamps
    end

    add_index :chronicle_api_routes, [:path, :http_method], unique: true, name: 'index_chronicle_api_routes_on_path_and_method'
  end
end
