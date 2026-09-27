require "spec_helper"
require "rolify/shared_examples/shared_examples_for_dynamic_shortcuts"

describe "Rolify dynamic shortcuts" do
  def user_class
    User
  end

  def role_class
    Role
  end

  it_behaves_like "Rolify.dynamic shortcuts"
end
