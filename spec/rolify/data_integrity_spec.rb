require "spec_helper"

# Uniqueness is enforced by the database, not only by the guards in add_role.
# These examples assert the constraints the ActiveRecord migration generator
# creates (see lib/generators/active_record/templates/migration.rb and
# spec/support/schema.rb, which mirrors it).
#
# A role is identified by its name at one of three mutually exclusive levels,
# and each level has its own partial unique index:
#
#   global     resource_type IS NULL     AND resource_id IS NULL
#   class      resource_type IS NOT NULL AND resource_id IS NULL
#   instance                                 resource_id IS NOT NULL
#
# The Role class used by the suite defines no validations, so an
# ActiveRecord::RecordNotUnique raised here can only come from the database.
describe "Rolify data integrity", :if => ENV['ADAPTER'] == 'active_record' do
  let(:user) { User.create!(:login => "data-integrity") }
  let(:forum) { Forum.first }
  let(:other_forum) { Forum.last }
  let(:group) { Group.first }

  let(:role_names) { %w[integrity integrity_scoped integrity_keep integrity_race] }

  after(:each) do
    user.roles = []
    user.destroy
    role_names.each { |role_name| Role.where(:name => role_name).destroy_all }
  end

  def global_attributes(role_name)
    { :name => role_name, :resource_type => nil, :resource_id => nil }
  end

  def class_attributes(role_name, resource_class)
    { :name => role_name, :resource_type => resource_class.to_s, :resource_id => nil }
  end

  def instance_attributes(role_name, resource)
    { :name => role_name, :resource_type => resource.class.to_s, :resource_id => resource.id }
  end

  describe "a duplicate at each scope level" do
    it "is rejected by the database for a global role" do
      Role.create!(global_attributes("integrity"))

      expect {
        Role.create!(global_attributes("integrity"))
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "is rejected by the database for a class scoped role" do
      Role.create!(class_attributes("integrity", Forum))

      expect {
        Role.create!(class_attributes("integrity", Forum))
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "is rejected by the database for an instance scoped role" do
      Role.create!(instance_attributes("integrity", forum))

      expect {
        Role.create!(instance_attributes("integrity", forum))
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "roles at different scopes" do
    it "lets two different global roles coexist" do
      Role.create!(global_attributes("integrity"))
      Role.create!(global_attributes("integrity_scoped"))

      expect(Role.where(:name => role_names).count).to eq(2)
    end

    it "lets the same role name be scoped to two different resource classes" do
      Role.create!(class_attributes("integrity", Forum))
      Role.create!(class_attributes("integrity", Group))

      expect(Role.where(:name => "integrity").count).to eq(2)
    end

    it "lets the same role name be scoped to two instances of one class" do
      Role.create!(instance_attributes("integrity", forum))
      Role.create!(instance_attributes("integrity", other_forum))

      expect(Role.where(:name => "integrity").count).to eq(2)
    end

    it "lets one role name be held globally, by a class and by an instance at once" do
      Role.create!(global_attributes("integrity"))
      Role.create!(class_attributes("integrity", Forum))
      Role.create!(instance_attributes("integrity", forum))

      expect(Role.where(:name => "integrity").count).to eq(3)
    end

    it "never lets a narrower scope stand in for a wider one" do
      Role.create!(class_attributes("integrity", Forum))
      Role.create!(instance_attributes("integrity", forum))

      expect(Role.where(:name => "integrity", :resource_id => nil).count).to eq(1)
      expect(Role.where(:name => "integrity").where.not(:resource_id => nil).count).to eq(1)
    end
  end

  describe "role creation through the adapter" do
    it "stores a single row when the same instance scoped role is added twice" do
      user.add_role(:integrity, forum)

      expect {
        user.add_role(:integrity, forum)
      }.not_to change { Role.where(:name => "integrity").count }
    end

    it "stores a single row when the same global role is added twice" do
      user.add_role(:integrity)

      expect {
        user.add_role(:integrity)
      }.not_to change { Role.where(:name => "integrity").count }
    end

    it "stores a single row when the same class scoped role is added twice" do
      user.add_role(:integrity, Forum)

      expect {
        user.add_role(:integrity, Forum)
      }.not_to change { Role.where(:name => "integrity").count }
    end

    it "still allows the same role name on a different resource" do
      user.add_role(:integrity, forum)

      expect {
        user.add_role(:integrity, other_forum)
      }.to change { Role.where(:name => "integrity").count }.by(1)
    end

    it "reuses the existing row for a role that already exists" do
      role = user.add_role(:integrity, forum)

      expect(User.adapter.find_or_create_by("integrity", "Forum", forum.id)).to eq(role)
    end
  end

  # A real thread race cannot be made deterministic against an in-memory
  # database, so the race is covered by its two halves instead: the database
  # rejects the losing insert, and the fallback the adapter takes after that
  # rejection returns the row that won.
  describe "concurrent creation of the same role" do
    {
      "global"          => [ "integrity_race", nil, nil ],
      "class scoped"    => [ "integrity_race", "Forum", nil ],
      "instance scoped" => [ "integrity_race", "Forum", :forum ]
    }.each do |level, (role_name, resource_type, resource)|
      context "at the #{level} level" do
        let(:attributes) do
          {
            :name => role_name,
            :resource_type => resource_type,
            :resource_id => (resource.is_a?(Symbol) ? send(resource).id : resource)
          }
        end

        it "rejects the losing insert with a unique violation" do
          Role.create!(attributes)

          expect { Role.create!(attributes) }.to raise_error(ActiveRecord::RecordNotUnique)
        end

        it "recovers from the violation and returns the winning row" do
          winner = Role.create!(attributes)

          expect(Role.create_or_find_by(attributes)).to eq(winner)
        end

        it "leaves exactly one row behind" do
          winner = Role.create!(attributes)
          Role.create_or_find_by(attributes)

          expect(Role.where(:name => role_name).to_a).to eq([ winner ])
        end
      end
    end
  end

  describe "role assignment" do
    it "records the assignment once when the same role is added twice" do
      user.add_role(:integrity)
      user.add_role(:integrity)

      expect(user.roles.reload.where(:name => "integrity").count).to eq(1)
    end

    it "is rejected by the database when inserted twice" do
      role = user.add_role(:integrity)

      expect {
        Role.connection.execute("INSERT INTO users_roles (user_id, role_id) VALUES (#{user.id}, #{role.id})")
      }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end
