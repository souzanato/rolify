ActiveRecord::Schema.define do
  self.verbose = false

  # Mirrors what the ActiveRecord migration generator produces, unique indexes
  # included, so that the suite exercises the same constraints a real app gets.
  # One partial unique index per scope level; a single index over all three
  # columns cannot enforce the global and class scoped levels, because NULLs
  # compare as distinct.
  [ :roles, :privileges, :admin_rights ].each do |table|
    create_table(table) do |t|
    t.string :name
    t.references :resource, :polymorphic => true

    t.timestamps null: false
    end

    add_index(table, :name)
    add_index(table, [ :name ], :unique => true,
              :where => "resource_type IS NULL AND resource_id IS NULL",
              :name => "index_#{table}_global")
    add_index(table, [ :name, :resource_type ], :unique => true,
              :where => "resource_type IS NOT NULL AND resource_id IS NULL",
              :name => "index_#{table}_class_scoped")
    add_index(table, [ :name, :resource_type, :resource_id ], :unique => true,
              :where => "resource_id IS NOT NULL",
              :name => "index_#{table}_instance_scoped")
  end

  [ :users, :human_resources, :customers, :admin_moderators, :strict_users ].each do |table|
    create_table(table) do |t|
      t.string :login
    end
  end

  create_table(:users_roles, :id => false) do |t|
    t.references :user
    t.references :role
  end
  add_index(:users_roles, [ :user_id, :role_id ], :unique => true)

  create_table(:strict_users_roles, :id => false) do |t|
    t.references :strict_user
    t.references :role
  end
  add_index(:strict_users_roles, [ :strict_user_id, :role_id ], :unique => true)

  create_table(:human_resources_roles, :id => false) do |t|
    t.references :human_resource
    t.references :role
  end
  add_index(:human_resources_roles, [ :human_resource_id, :role_id ], :unique => true)

  create_table(:customers_privileges, :id => false) do |t|
    t.references :customer
    t.references :privilege
  end
  add_index(:customers_privileges, [ :customer_id, :privilege_id ], :unique => true)

  create_table(:moderators_rights, :id => false) do |t|
    t.references :moderator
    t.references :right
  end
  add_index(:moderators_rights, [ :moderator_id, :right_id ], :unique => true)

  create_table(:forums) do |t|
    t.string :name
  end

  create_table(:groups) do |t|
    t.integer :parent_id
    t.string :name
  end

  create_table(:teams, :id => false) do |t|
    t.primary_key :team_code
    t.string :name
  end

  create_table(:organizations) do |t|
    t.string :type
  end
end
