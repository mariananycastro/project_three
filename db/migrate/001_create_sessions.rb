class CreateSessions < ActiveRecord::Migration[6.0]
  def change
    create_table :sessions do |t|
      t.string   :email, null: false
      t.string   :session_id_digest, null: false
      t.datetime :expires_at, null: false
      t.timestamps null: false
    end
  end
end
