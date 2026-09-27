require "rolify/configure"

module Rolify
  module Dynamic
    # Only role names that can be addressed as a dynamic shortcut are turned
    # into methods. This mirrors the patterns `Rolify::Role#method_missing`
    # and `#respond_to?` dispatch on, so we never publish a method that cannot
    # be called through normal Ruby syntax. Role names containing spaces,
    # hyphens or other punctuation stay queryable through `has_role?`.
    METHOD_SAFE_ROLE_NAME = /\A\w+\z/

    def define_dynamic_method(role_name, resource)
      return unless METHOD_SAFE_ROLE_NAME.match?(role_name.to_s)

      class_eval do
        define_method("is_#{role_name}?".to_sym) do
          has_role?("#{role_name}")
        end if !method_defined?("is_#{role_name}?".to_sym) && self.adapter.where_strict(self.role_class, name: role_name).exists?

        define_method("is_#{role_name}_of?".to_sym) do |arg|
          has_role?("#{role_name}", arg)
        end if !method_defined?("is_#{role_name}_of?".to_sym) && resource && self.adapter.where_strict(self.role_class, name: role_name, resource: resource).exists?
      end
    end
  end
end
