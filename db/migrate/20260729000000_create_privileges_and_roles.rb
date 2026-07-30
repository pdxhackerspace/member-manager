class CreatePrivilegesAndRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :privileges do |t|
      t.string :category
      t.datetime :created_at, null: false
      t.text :description
      t.string :key, null: false
      t.string :label, null: false
      t.string :privilege_scope, null: false, default: 'global'
      t.datetime :updated_at, null: false

      t.index :key, unique: true
      t.index :privilege_scope
    end

    create_table :roles do |t|
      t.datetime :created_at, null: false
      t.text :description
      t.string :name, null: false
      t.datetime :updated_at, null: false

      t.index :name, unique: true
    end

    create_table :role_privileges do |t|
      t.datetime :created_at, null: false
      t.references :privilege, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true
      t.datetime :updated_at, null: false

      t.index %i[role_id privilege_id], unique: true
    end

    create_table :training_topic_roles do |t|
      t.datetime :created_at, null: false
      t.string :member_source, null: false
      t.references :role, null: false, foreign_key: true
      t.references :training_topic, null: false, foreign_key: true
      t.datetime :updated_at, null: false

      t.index %i[training_topic_id role_id member_source], unique: true,
              name: 'index_training_topic_roles_on_topic_role_source'
    end
  end
end
