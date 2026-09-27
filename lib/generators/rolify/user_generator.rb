require 'rails/generators/migration'
require 'active_support/core_ext'

module Rolify
  module Generators
    class UserGenerator < Rails::Generators::NamedBase
      argument :role_cname, :type => :string, :default => "Role"

      # Rails replaces `:default` with the value from the application's
      # generator configuration before Thor ever sees it, and that value is a
      # boolean when no ORM has been configured. The declared String default is
      # therefore only a fallback, so tell Thor not to reject the real default
      # instead of pretending the type always matches.
      class_option :orm, :type => :string, :default => "active_record", :check_default_type => false

      desc "Inject rolify method in the User class."

      def inject_user_content
        inject_into_file(model_path, :after => inject_rolify_method) do
          "  rolify#{role_association}\n"
        end
      end
      
      def inject_rolify_method
        if active_record?
          /class #{class_name.camelize}\n|class #{class_name.camelize} .*\n|class #{class_name.demodulize.camelize}\n|class #{class_name.demodulize.camelize} .*\n/
        else
          /include Mongoid::Document\n|include Mongoid::Document .*\n/
        end
      end
      
      def model_path
        File.join("app", "models", "#{file_path}.rb")
      end
      
      def role_association
        if role_cname != "Role"
          " :role_cname => '#{role_cname.camelize}'"
        else
          ""
        end
      end

      private

      # ActiveRecord is the default. `--orm` only carries a value when it is
      # given on the command line, and Thor hands that over as a String while
      # Rails' own configuration stores a Symbol, so compare string forms.
      def active_record?
        options.orm.nil? || options.orm == false || options.orm.to_s == "active_record"
      end
    end
  end
end
