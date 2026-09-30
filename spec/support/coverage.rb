# Shared coverage bootstrapping.
#
# `spec_helper.rb` and `generators_helper.rb` are separate RSpec entry points,
# but they can be loaded into the same process (e.g. `rspec spec`). SimpleCov
# refuses to start twice, so only start it when coverage is not already on.
require 'simplecov'

unless Coverage.running?
  SimpleCov.start do
    skip '/spec/'
    skip '/gemfiles/'
  end
end
