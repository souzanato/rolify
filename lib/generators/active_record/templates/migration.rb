class RolifyCreate<%= table_name.camelize %> < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table(:<%= table_name %>) do |t|
      t.string :name
      t.references :resource, :polymorphic => true

      t.timestamps
    end

    create_table(:<%= join_table %>, :id => false) do |t|
      t.references :<%= user_reference %>
      t.references :<%= role_reference %>
    end
    <% if ActiveRecord::Base.connection.class.to_s.demodulize != 'PostgreSQLAdapter' %><%= "\n    " %>add_index(:<%= table_name %>, :name)<% end %>
    # A role is identified by its name and the resource it is scoped to, and a
    # scoped role is assigned to a user only once. These two unique indexes
    # enforce both, so concurrent calls cannot insert duplicates.
    #
    # Global roles (resource_type and resource_id both NULL) are not covered:
    # databases treat NULLs as distinct in a unique index.
    add_index(:<%= table_name %>, [ :name, :resource_type, :resource_id ], :unique => true)
    add_index(:<%= join_table %>, [ :<%= user_reference %>_id, :<%= role_reference %>_id ], :unique => true)
  end
end
