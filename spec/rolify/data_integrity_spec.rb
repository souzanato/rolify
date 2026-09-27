require "spec_helper"

# Uniqueness is enforced by the database, not only by the guards in
# add_role. These examples assert the constraints the ActiveRecord migration
# generator creates (see lib/generators/active_record/templates/migration.rb
# and spec/support/schema.rb, which mirrors it).
describe "Rolify data integrity", :if => ENV['ADAPTER'] == 'active_record' do
  let(:user) { User.create!(:login => "data-integrity") }
  let(:forum) { Forum.first }

  after(:each) do
    user.roles = []
    user.destroy
    Role.where(:name => "integrity").destroy_all
  end

  describe "role scoped to a resource" do
    it "stores a single row when the same role is added twice" do
      user.add_role(:integrity, forum)

      expect {
        user.add_role(:integrity, forum)
      }.not_to change { Role.where(:name => "integrity").count }
    end

    it "is rejected by the database when inserted twice" do
      user.add_role(:integrity, forum)

      expect {
        Role.create!(:name => "integrity", :resource_type => "Forum", :resource_id => forum.id)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "still allows the same role name on a different resource" do
      user.add_role(:integrity, forum)

      expect {
        user.add_role(:integrity, Forum.last)
      }.to change { Role.where(:name => "integrity").count }.by(1)
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

  describe "role creation" do
    it "recovers from an insert race instead of raising" do
      role = user.add_role(:integrity, forum)
      attributes = { :name => "integrity", :resource_type => "Forum", :resource_id => forum.id }

      # This is the fallback the adapter takes when its initial lookup misses
      # because another process inserted the row first: the insert is rejected
      # by the unique index and the row that won is returned.
      expect(Role.create_or_find_by(attributes)).to eq(role)
    end

    it "reuses the existing row for a role that already exists" do
      role = user.add_role(:integrity, forum)

      expect(User.adapter.find_or_create_by("integrity", "Forum", forum.id)).to eq(role)
    end
  end
end
