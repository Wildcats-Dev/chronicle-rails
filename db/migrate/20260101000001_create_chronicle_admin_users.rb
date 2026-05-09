class CreateChronicleAdminUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :chronicle_admin_users do |t|
      t.string :email,           null: false
      t.string :name,            null: false
      t.string :password_digest, null: false
      t.string :auth_token,      null: false
      t.integer :role,           default: 0, null: false

      t.timestamps
    end

    add_index :chronicle_admin_users, :email,      unique: true
    add_index :chronicle_admin_users, :auth_token, unique: true
  end
end
