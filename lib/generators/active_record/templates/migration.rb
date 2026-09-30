<%
  # Only some adapters support partial indexes, and ActiveRecord silently drops
  # the :where option on the others - which would turn each of these into a full
  # unique index and collapse the three scope levels into one. So the branch has
  # to be decided here, at generation time.
  supports_partial_indexes =
    ActiveRecord::Base.connection.respond_to?(:supports_partial_index?) &&
    ActiveRecord::Base.connection.supports_partial_index?
-%>
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

    # Not redundant with the unique indexes below: those are partial, so none of
    # them can answer a lookup by name alone.
    add_index(:<%= table_name %>, :name)
<% if supports_partial_indexes -%>

    # A role is identified by its name at one of three mutually exclusive
    # levels, so each level gets its own partial unique index:
    #
    #   global     resource_type IS NULL     AND resource_id IS NULL
    #   class      resource_type IS NOT NULL AND resource_id IS NULL
    #   instance                                 resource_id IS NOT NULL
    #
    # One index over all three columns cannot replace these. NULLs compare as
    # distinct in a unique index, so it would let two concurrent creations of
    # the same global or class scoped role both succeed.
    #
    # The predicates are mutually exclusive, so the same role name can still be
    # held at every level at once.
    add_index(:<%= table_name %>, [ :name ],
              :unique => true,
              :where => "resource_type IS NULL AND resource_id IS NULL",
              :name => "index_<%= table_name %>_global")
    add_index(:<%= table_name %>, [ :name, :resource_type ],
              :unique => true,
              :where => "resource_type IS NOT NULL AND resource_id IS NULL",
              :name => "index_<%= table_name %>_class_scoped")
    add_index(:<%= table_name %>, [ :name, :resource_type, :resource_id ],
              :unique => true,
              :where => "resource_id IS NOT NULL",
              :name => "index_<%= table_name %>_instance_scoped")
<% else -%>

    # This adapter has no partial indexes, so the three levels cannot be
    # enforced separately in the database. This index covers instance scoped
    # roles, whose three columns are all non-NULL. Global and class scoped roles
    # still rely on Rolify's find_or_create_by, so two concurrent creations of
    # one of those can leave duplicates: add a uniqueness validation on the Role
    # model if you need them guaranteed.
    add_index(:<%= table_name %>, [ :name, :resource_type, :resource_id ], :unique => true)
<% end -%>
    add_index(:<%= join_table %>, [ :<%= user_reference %>_id, :<%= role_reference %>_id ], :unique => true)
  end
end
