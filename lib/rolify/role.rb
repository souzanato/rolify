require "rolify/finders"
require "rolify/utils"

module Rolify
  module Role
    extend Utils

    def self.included(base)
      base.extend Finders
    end

    def add_role(role_name, resource = nil)
      role = self.class.adapter.find_or_create_by(role_name.to_s,
                                                  (resource.is_a?(Class) ? resource.to_s : resource.class.name if resource),
                                                  (resource.id if resource && !resource.is_a?(Class)))

      if !roles.include?(role)
        self.class.define_dynamic_method(role_name, resource) if Rolify.dynamic_shortcuts
        self.class.adapter.add(self, role)
      end
      role
    end
    alias_method :grant, :add_role

    def has_role?(role_name, resource = nil)
      return has_strict_role?(role_name, resource) if self.class.strict_rolify and resource and resource != :any

      if new_record?
        role_array = self.roles.detect { |r|
          r.name.to_s == role_name.to_s &&
            (r.resource == resource ||
             resource.nil? ||
             (resource == :any && r.resource.present?))
        }
      else
        role_array = self.class.adapter.where(self.roles, name: role_name, resource: resource)
      end

      return false if role_array.nil?
      role_array != []
    end

    def has_strict_role?(role_name, resource)
      self.class.adapter.where_strict(self.roles, name: role_name, resource: resource).any?
    end

    def has_cached_role?(role_name, resource = nil)
      return has_strict_cached_role?(role_name, resource) if self.class.strict_rolify and resource and resource != :any
      self.class.adapter.find_cached(self.roles, name: role_name, resource: resource).any?
    end

    def has_strict_cached_role?(role_name, resource = nil)
      self.class.adapter.find_cached_strict(self.roles, name: role_name, resource: resource).any?
    end

    def has_all_roles?(*args)
      args.each do |arg|
        if arg.is_a? Hash
          return false if !self.has_role?(arg[:name], arg[:resource])
        elsif arg.is_a?(String) || arg.is_a?(Symbol)
          return false if !self.has_role?(arg)
        else
          raise ArgumentError, "Invalid argument type: only hash or string or symbol allowed"
        end
      end
      true
    end

    def has_any_role?(*args)
      if new_record?
        args.any? { |r| self.has_role?(r) }
      else
        self.class.adapter.where(self.roles, *args).size > 0
      end
    end

    def only_has_role?(role_name, resource = nil)
      return self.has_role?(role_name,resource) && self.roles.count == 1
    end

    def remove_role(role_name, resource = nil)
      self.class.adapter.remove(self, role_name.to_s, resource)
    end

    alias_method :revoke, :remove_role
    deprecate :has_no_role, :remove_role

    def roles_name
      self.roles.pluck(:name)
    end

    def method_missing(method, *args, &block)
      if Rolify.dynamic_shortcuts && (role_name = dynamic_role_name(method))
        resource = args.first
        self.class.define_dynamic_method role_name, resource
        return has_role?(role_name, resource)
      end
      super
    end

    def respond_to_missing?(method, include_private = false)
      return super unless Rolify.dynamic_shortcuts
      return super unless dynamic_role_name(method)

      dynamic_role_available?(method)
    end

    def respond_to?(method, include_private = false)
      if Rolify.dynamic_shortcuts && dynamic_role_name(method)
        # Deliberately not delegating to `respond_to_missing?`: a shortcut that
        # was already defined stays defined after its last role is removed, and
        # must keep answering false.
        dynamic_role_available?(method)
      else
        super
      end
    end

    private

    # `is_<role>_of?` is tested first: `\w` would otherwise swallow the `_of`
    # suffix into the role name.
    DYNAMIC_ROLE_OF_METHOD = /\Ais_(\w+)_of\?\z/
    DYNAMIC_ROLE_METHOD    = /\Ais_(\w+)\?\z/

    def dynamic_role_name(method)
      name = method.to_s
      match = DYNAMIC_ROLE_OF_METHOD.match(name) || DYNAMIC_ROLE_METHOD.match(name)
      match && match[1]
    end

    def dynamic_role_of_method?(method)
      DYNAMIC_ROLE_OF_METHOD.match?(method.to_s)
    end

    def dynamic_role_available?(method)
      query = self.class.role_class.where(:name => dynamic_role_name(method))
      query = self.class.adapter.exists?(query, :resource_type) if dynamic_role_of_method?(method)
      query.count > 0
    end
  end
end
