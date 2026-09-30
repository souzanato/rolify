# Edge cases for the dynamic shortcut API (`is_<role>?` / `is_<role>_of?`).
#
# A dynamic shortcut is only published for a role name that can be spelled as
# a Ruby method name. Every other name stays reachable through add_role and
# has_role?; it is simply never turned into a method.
# Role names used by these examples. They are unique to this file; `a` is
# deliberate, because it makes the shortcut `is_a?`, which collides with
# Kernel#is_a?.
DYNAMIC_SHORTCUT_VALID_ROLE_NAMES   = %w[edge_plain edge_scoped edge_dangling edge_disabled edge_missing a].freeze
DYNAMIC_SHORTCUT_INVALID_ROLE_NAMES = ["site admin", "site-admin", "admin!", "café"].freeze

shared_examples_for "Rolify.dynamic shortcuts" do
  before(:all) do
    @previous_dynamic_shortcuts = Rolify.dynamic_shortcuts

    # Dynamic shortcuts are only published when they are enabled before the
    # model is rolified, because that is when Rolify::Dynamic is mixed in.
    Rolify.dynamic_shortcuts = true
    rolify_options = { :role_cname => role_class.to_s }
    rolify_options[:role_join_table_name] = join_table if defined?(join_table)
    silence_warnings { user_class.rolify rolify_options }
  end

  after(:all) do
    Rolify.dynamic_shortcuts = @previous_dynamic_shortcuts
  end

  # A dedicated user, so that these examples never disturb the fixtures the
  # rest of the suite shares.
  let(:user) { user_class.create!(:login => "dynamic-shortcuts") }

  after(:each) do
    user.roles = []
    user.destroy
    (DYNAMIC_SHORTCUT_VALID_ROLE_NAMES + DYNAMIC_SHORTCUT_INVALID_ROLE_NAMES).each do |role_name|
      role_class.where(:name => role_name).destroy_all
    end
  end

  describe "with a role name that is a valid method name" do
    it "publishes both shortcuts" do
      user.add_role(:edge_plain)
      expect(user.is_edge_plain?).to be true
      expect(user.respond_to?(:is_edge_plain?)).to be true

      user.add_role(:edge_scoped, Forum.first)
      expect(user.is_edge_scoped_of?(Forum.first)).to be true
      expect(user.is_edge_scoped_of?(Forum.last)).to be false
      expect(user.respond_to?(:is_edge_scoped_of?)).to be true
    end

    it "keeps the shortcut callable after the last role is removed, but stops advertising it" do
      user.add_role(:edge_plain)
      user.remove_role(:edge_plain)

      expect(user.is_edge_plain?).to be false
      expect(user.respond_to?(:is_edge_plain?)).to be false
    end

    it "resolves a shortcut for a role granted outside this process" do
      # Naming the role directly, rather than through add_role, means no
      # shortcut has been defined on the class yet.
      role_class.create!(:name => "edge_dangling")

      expect(user.respond_to?(:is_edge_dangling?)).to be true
      expect(user.method(:is_edge_dangling?)).to be_a(Method)
      expect(user.method(:is_edge_dangling?).call).to be false
    end

    it "returns false, rather than raising, for a shortcut with no matching role" do
      expect(user.is_edge_missing?).to be false
      expect(user.is_edge_missing_of?(Forum)).to be false
    end

    it "does not redefine an existing method that looks like a shortcut" do
      owner_before = user.method(:is_a?).owner

      user.add_role(:a)

      expect(user.method(:is_a?).owner).to eq(owner_before)
      expect(user.is_a?(user_class)).to be true
      expect(user.is_a?(String)).to be false
    end
  end

  describe "with a role name that is not a valid method name" do
    DYNAMIC_SHORTCUT_INVALID_ROLE_NAMES.each do |role_name|
      context "such as #{role_name.inspect}" do
        it "still grants and reports the role" do
          user.add_role(role_name)
          expect(user.has_role?(role_name)).to be true
        end

        it "publishes no dynamic shortcut for it" do
          user.add_role(role_name)

          expect(user.respond_to?(:"is_#{role_name}?")).to be false
          expect { user.public_send(:"is_#{role_name}?") }.to raise_error(NoMethodError)
        end

        it "can still be removed" do
          user.add_role(role_name)
          user.remove_role(role_name)
          expect(user.has_role?(role_name)).to be false
        end
      end
    end
  end

  describe "with dynamic shortcuts disabled" do
    around do |example|
      Rolify.dynamic_shortcuts = false
      example.run
    ensure
      Rolify.dynamic_shortcuts = true
    end

    it "does not answer shortcut calls or advertise them" do
      # Granted while shortcuts are off, so no method is defined for it.
      user.add_role(:edge_disabled)

      expect(user.respond_to?(:is_edge_disabled?)).to be false
      expect { user.is_edge_disabled? }.to raise_error(NoMethodError)
    end
  end
end
