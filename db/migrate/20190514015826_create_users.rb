class CreateUsers < ActiveRecord::Migration[5.1]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.string :line_user_id, null: false, index: { unique: true }

      t.timestamps
    end
  end
end
