require 'generators_helper'

# Generators are not automatically loaded by Rails
require 'generators/rolify/rolify_generator'

describe Rolify::Generators::RolifyGenerator, :if => ENV['ADAPTER'] == 'active_record' do
  # Tell the generator where to put its output (what it thinks of as Rails.root)
  destination File.expand_path("../../../../tmp", __FILE__)
  teardown :cleanup_destination_root

  let(:supports_partial_indexes) { true }
  before {
    prepare_destination
  }

  def cleanup_destination_root
    FileUtils.rm_rf destination_root
  end

  # Runs a generated migration against the in-memory database and returns the
  # indexes of each table it touched. Executing the file is a stronger check
  # than matching its text: it proves the migration runs and that the database
  # ends up with the constraints the file claims to create.
  def run_generated_migration(path, *tables)
    tables.each { |table| ActiveRecord::Base.connection.drop_table(table, :if_exists => true) }
    load path.to_s
    name = File.basename(path.to_s).sub(/\A\d+_/, "").sub(/\.rb\z/, "").camelize
    capture(:stdout) { Object.const_get(name).new.migrate(:up) }
    tables.flat_map do |table|
      ActiveRecord::Base.connection.indexes(table).map do |index|
        [ table, index.columns, index.unique, index.where ]
      end
    end
  end

  describe 'specifying only Role class name' do
    before(:all) { arguments %w(Role) }

    before {
      allow(ActiveRecord::Base.connection).to receive(:supports_partial_index?).and_return(supports_partial_indexes)
      capture(:stdout) {
        generator.create_file "app/models/user.rb" do
          <<-RUBY
          class User < ActiveRecord::Base
          end
          RUBY
        end
      }
      require File.join(destination_root, "app/models/user.rb")
      if Rails::VERSION::MAJOR >= 7
        run_generator %w(--skip-collision-check)
      else
        run_generator
      end
    }

    describe 'config/initializers/rolify.rb' do
      subject { file('config/initializers/rolify.rb') }
      it { should exist }
      it { should contain "Rolify.configure do |config|"}
      it { should contain "# config.use_dynamic_shortcuts" }
      it { should contain "# config.use_mongoid" }
    end

    describe 'app/models/role.rb' do
      subject { file('app/models/role.rb') }
      it { should exist }
      it do
        if Rails::VERSION::MAJOR < 5
          should contain "class Role < ActiveRecord::Base"
        else
          should contain "class Role < ApplicationRecord"
        end
      end
      it { should contain "has_and_belongs_to_many :users, :join_table => :users_roles" }
      it do
        if Rails::VERSION::MAJOR < 5
          should contain "belongs_to :resource,\n"
                          "           :polymorphic => true"
        else
          should contain "belongs_to :resource,\n"
                          "           :polymorphic => true,\n"
                          "           :optional => true"
        end
      end
      it { should contain "belongs_to :resource,\n"
                          "           :polymorphic => true,\n"
                          "           :optional => true"
      }
      it { should contain "validates :resource_type,\n"
                          "          :inclusion => { :in => Rolify.resource_types },\n"
                          "          :allow_nil => true" }
      it { should contain "scopify" }
    end

    describe 'app/models/user.rb' do
      subject { file('app/models/user.rb') }
      it { should contain /class User < ActiveRecord::Base\n  rolify\n/ }
    end

    describe 'migration file' do
      subject { migration_file('db/migrate/rolify_create_roles.rb') }

      it { should be_a_migration }
      it { should contain "create_table(:roles) do" }
      it { should contain "create_table(:users_roles, :id => false) do" }
      it { should contain 'add_index(:roles, :name)' }
      it { should contain 'add_index(:users_roles, [ :user_id, :role_id ], :unique => true)' }

      context 'an adapter with partial indexes' do
        it 'declares one unique index per scope level' do
          expect(subject).to contain(':name => "index_roles_global"')
          expect(subject).to contain(':name => "index_roles_class_scoped"')
          expect(subject).to contain(':name => "index_roles_instance_scoped"')

          expect(subject).to contain('resource_type IS NULL AND resource_id IS NULL')
          expect(subject).to contain('resource_type IS NOT NULL AND resource_id IS NULL')
          expect(subject).to contain('resource_id IS NOT NULL')
        end

        it 'enforces one unique index per scope level once migrated' do
          indexes = run_generated_migration(subject, :roles, :users_roles)

          expect(indexes).to include(
            [ :roles, [ 'name' ], true, 'resource_type IS NULL AND resource_id IS NULL' ],
            [ :roles, [ 'name', 'resource_type' ], true, 'resource_type IS NOT NULL AND resource_id IS NULL' ],
            [ :roles, [ 'name', 'resource_type', 'resource_id' ], true, 'resource_id IS NOT NULL' ],
            [ :users_roles, [ 'user_id', 'role_id' ], true, nil ]
          )
        end
      end

      context 'an adapter without partial indexes' do
        let(:supports_partial_indexes) { false }

        it 'falls back to the composite unique index' do
          expect(subject).to contain('add_index(:roles, [ :name, :resource_type, :resource_id ], :unique => true)')
          expect(subject).not_to contain(':where =>')
        end

        it 'creates only that composite index once migrated' do
          indexes = run_generated_migration(subject, :roles, :users_roles)

          expect(indexes).to include([ :roles, [ 'name', 'resource_type', 'resource_id' ], true, nil ])
          expect(indexes.select { |table, _, unique, where| table == :roles && unique && where }.size).to eq(0)
        end
      end
    end
  end

  describe 'specifying the orm explicitly' do
    before(:all) { arguments %w(Role User --orm=active_record) }

    before {
      allow(ActiveRecord::Base.connection).to receive(:supports_partial_index?).and_return(supports_partial_indexes)
      capture(:stdout) {
        generator.create_file "app/models/user.rb" do
          "class User < ActiveRecord::Base\nend"
        end
      }
      require File.join(destination_root, "app/models/user.rb")
      run_generator %w(--skip-collision-check)
    }

    it 'injects the rolify call into the user model' do
      expect(file('app/models/user.rb')).to contain /class User < ActiveRecord::Base\n  rolify\n/
    end
  end

  describe 'specifying User and Role class names' do
    before(:all) { arguments %w(AdminRole AdminUser) }

    before {
      allow(ActiveRecord::Base.connection).to receive(:supports_partial_index?).and_return(supports_partial_indexes)
      capture(:stdout) {
        generator.create_file "app/models/admin_user.rb" do
          "class AdminUser < ActiveRecord::Base\nend"
        end
      }
      require File.join(destination_root, "app/models/admin_user.rb")
      run_generator
    }

    describe 'config/initializers/rolify.rb' do
      subject { file('config/initializers/rolify.rb') }

      it { should exist }
      it { should contain "Rolify.configure(\"AdminRole\") do |config|"}
      it { should contain "# config.use_dynamic_shortcuts" }
      it { should contain "# config.use_mongoid" }
    end

    describe 'app/models/admin_role.rb' do
      subject { file('app/models/admin_role.rb') }

      it { should exist }
      it do
        if Rails::VERSION::MAJOR < 5
          should contain "class AdminRole < ActiveRecord::Base"
        else
          should contain "class AdminRole < ApplicationRecord"
        end
      end
      it { should contain "has_and_belongs_to_many :admin_users, :join_table => :admin_users_admin_roles" }
      it { should contain "belongs_to :resource,\n"
                          "           :polymorphic => true,\n"
                          "           :optional => true"
      }
    end

    describe 'app/models/admin_user.rb' do
      subject { file('app/models/admin_user.rb') }

      it { should contain /class AdminUser < ActiveRecord::Base\n  rolify :role_cname => 'AdminRole'\n/ }
    end

    describe 'migration file' do
      subject { migration_file('db/migrate/rolify_create_admin_roles.rb') }

      it { should be_a_migration }
      it { should contain "create_table(:admin_roles)" }
      it { should contain "create_table(:admin_users_admin_roles, :id => false) do" }

      context 'an adapter with partial indexes' do
        it 'names the scope indexes after the role table' do
          expect(subject).to contain(':name => "index_admin_roles_global"')
          expect(subject).to contain(':name => "index_admin_roles_class_scoped"')
          expect(subject).to contain(':name => "index_admin_roles_instance_scoped"')
        end
      end

      context 'an adapter without partial indexes' do
        let(:supports_partial_indexes) { false }

        it 'falls back to the composite unique index' do
          expect(subject).to contain('add_index(:admin_roles, [ :name, :resource_type, :resource_id ], :unique => true)')
          expect(subject).not_to contain(':where =>')
        end
      end
    end
  end

  describe 'specifying namespaced User and Role class names' do
    before(:all) { arguments %w(Admin::Role Admin::User) }

    before {
      allow(ActiveRecord::Base.connection).to receive(:supports_partial_index?).and_return(supports_partial_indexes)
      capture(:stdout) {
        generator.create_file "app/models/admin/user.rb" do
          <<-RUBY
          module Admin
            class User < ActiveRecord::Base
              self.table_name_prefix = 'admin_'
            end
          end
          RUBY
        end
      }
      require File.join(destination_root, "app/models/admin/user.rb")
      run_generator
    }

    describe 'config/initializers/rolify.rb' do
      subject { file('config/initializers/rolify.rb') }

      it { should exist }
      it { should contain "Rolify.configure(\"Admin::Role\") do |config|"}
      it { should contain "# config.use_dynamic_shortcuts" }
      it { should contain "# config.use_mongoid" }
    end

    describe 'app/models/admin/role.rb' do
      subject { file('app/models/admin/role.rb') }

      it { should exist }
      it do
        if Rails::VERSION::MAJOR < 5
          should contain "class Admin::Role < ActiveRecord::Base"
        else
          should contain "class Admin::Role < ApplicationRecord"
        end
      end
      it { should contain "has_and_belongs_to_many :admin_users, :join_table => :admin_users_admin_roles" }
      it { should contain "belongs_to :resource,\n"
                          "           :polymorphic => true,\n"
                          "           :optional => true"
      }
    end

    describe 'app/models/admin/user.rb' do
      subject { file('app/models/admin/user.rb') }

      it { should contain /class User < ActiveRecord::Base\n  rolify :role_cname => 'Admin::Role'\n/ }
    end

    describe 'migration file' do
      subject { migration_file('db/migrate/rolify_create_admin_roles.rb') }

      it { should be_a_migration }
      it { should contain "create_table(:admin_roles)" }
      it { should contain "create_table(:admin_users_admin_roles, :id => false) do" }
      it do
        if Rails::VERSION::MAJOR < 5
          should contain "< ActiveRecord::Migration"
        else
          should contain "< ActiveRecord::Migration[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
        end
      end

      context 'an adapter with partial indexes' do
        it 'names the scope indexes after the namespaced role table' do
          expect(subject).to contain(':name => "index_admin_roles_global"')
          expect(subject).to contain(':name => "index_admin_roles_class_scoped"')
          expect(subject).to contain(':name => "index_admin_roles_instance_scoped"')
        end
      end

      context 'an adapter without partial indexes' do
        let(:supports_partial_indexes) { false }

        it 'falls back to the composite unique index' do
          expect(subject).to contain('add_index(:admin_roles, [ :name, :resource_type, :resource_id ], :unique => true)')
          expect(subject).not_to contain(':where =>')
        end
      end
    end
  end
end
