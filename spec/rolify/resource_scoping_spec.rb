require "spec_helper"

# The public role scoping contract, exercised on a single user: a global role,
# a role scoped to a resource class and a role scoped to a resource instance
# never stand in for one another, and removing one leaves the others alone.
#
# Resource-side queries (with_role/without_role/find_roles) are covered by
# shared_examples_for_finders.
describe "Rolify resource scoping" do
  let(:user) { User.create!(:login => "resource-scoping") }
  let(:other_user) { User.create!(:login => "resource-scoping-other") }
  let(:forum_a) { Forum.first }
  let(:forum_b) { Forum.last }

  let(:role_names) do
    %w[scope_global scope_class scope_instance
       scope_dual scope_dual_class]
  end

  after(:each) do
    [user, other_user].each do |u|
      u.roles = []
      u.destroy
    end
    role_names.each { |role_name| Role.where(:name => role_name).destroy_all }
  end

  describe "a role granted at each scope" do
    before do
      user.add_role(:scope_global)
      user.add_role(:scope_class, Forum)
      user.add_role(:scope_instance, forum_a)
    end

    it "answers the query for the scope it was granted at" do
      expect(user.has_role?(:scope_global)).to be true
      expect(user.has_role?(:scope_class, Forum)).to be true
      expect(user.has_role?(:scope_instance, forum_a)).to be true
    end

    it "lets a global role satisfy a resource scoped query" do
      expect(user.has_role?(:scope_global, forum_a)).to be true
      expect(user.has_role?(:scope_global, Forum)).to be true
      expect(user.has_role?(:scope_global, :any)).to be true
    end

    it "lets a class scoped role satisfy a query for any of its instances" do
      expect(user.has_role?(:scope_class, forum_a)).to be true
      expect(user.has_role?(:scope_class, forum_b)).to be true
    end

    it "does not let a role leak to another resource class" do
      expect(user.has_role?(:scope_class, Group)).to be false
      expect(user.has_role?(:scope_instance, Group.first)).to be false
    end

    it "does not let an instance scoped role leak to a sibling instance" do
      expect(user.has_role?(:scope_instance, forum_b)).to be false
      expect(user.has_strict_role?(:scope_instance, forum_b)).to be false
    end

    it "does not answer a global or class scoped query with a narrower role" do
      expect(user.has_role?(:scope_instance)).to be false
      expect(user.has_role?(:scope_class)).to be false
      expect(user.has_role?(:scope_instance, Forum)).to be false
    end

    it "answers :any for every scope" do
      expect(user.has_role?(:scope_global, :any)).to be true
      expect(user.has_role?(:scope_class, :any)).to be true
      expect(user.has_role?(:scope_instance, :any)).to be true
    end

    it "does not grant anything to an unrelated user" do
      expect(other_user.has_role?(:scope_global)).to be false
      expect(other_user.has_role?(:scope_class, Forum)).to be false
      expect(other_user.has_role?(:scope_instance, forum_a)).to be false
      expect(other_user.has_role?(:scope_global, :any)).to be false
    end
  end

  describe "the same role name granted globally and on an instance" do
    before do
      user.add_role(:scope_dual)
      user.add_role(:scope_dual, forum_a)
    end

    it "holds both rows" do
      expect(user.roles.count).to eq(2)
    end

    it "reports the global role for every query, and the scoped one only in strict mode" do
      expect(user.has_role?(:scope_dual)).to be true
      expect(user.has_role?(:scope_dual, forum_a)).to be true
      expect(user.has_role?(:scope_dual, forum_b)).to be true

      expect(user.has_strict_role?(:scope_dual, forum_a)).to be true
      expect(user.has_strict_role?(:scope_dual, forum_b)).to be false
    end

    it "removes only the instance scoped role when asked for that scope" do
      user.remove_role(:scope_dual, forum_a)

      expect(user.has_strict_role?(:scope_dual, forum_a)).to be false
      expect(user.has_role?(:scope_dual)).to be true
      expect(user.roles.count).to eq(1)
    end

    it "removes the remaining global role when asked without a scope" do
      user.remove_role(:scope_dual, forum_a)
      user.remove_role(:scope_dual)

      expect(user.has_role?(:scope_dual)).to be false
      expect(user.roles.count).to eq(0)
    end
  end

  describe "the same role name granted globally and on a class" do
    before do
      user.add_role(:scope_dual_class)
      user.add_role(:scope_dual_class, Forum)
    end

    it "holds both rows" do
      expect(user.roles.count).to eq(2)
    end

    it "removes only the class scoped role when asked for that scope" do
      user.remove_role(:scope_dual_class, Forum)

      expect(user.has_strict_role?(:scope_dual_class, Forum)).to be false
      expect(user.has_role?(:scope_dual_class, Forum)).to be true
      expect(user.roles.count).to eq(1)
    end
  end
end
