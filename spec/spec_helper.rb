require 'rubygems'
require "bundler/setup"

require_relative 'support/coverage'

require 'rolify'
require 'rolify/matchers'
require "logger"
require 'rails'
require 'database_cleaner/active_record'

ENV['ADAPTER'] ||= 'active_record'

load File.dirname(__FILE__) + "/support/adapters/#{ENV['ADAPTER']}.rb"
load File.dirname(__FILE__) + '/support/data.rb'



def reset_defaults
  Rolify.use_defaults
  Rolify.use_mongoid if ENV['ADAPTER'] == 'mongoid'
end

def provision_user(user, roles)
  roles.each do |role|
    if role.is_a? Array
      user.add_role *role
    else
      user.add_role role
    end
  end
  user
end

def silence_warnings(&block)
  warn_level = $VERBOSE
  $VERBOSE = nil
  result = block.call
  $VERBOSE = warn_level
  result
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = [:should, :expect] }

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.start
  end

  config.after(:suite) do |example|
    DatabaseCleaner.clean
  end

end
