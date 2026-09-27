source "https://rubygems.org"

# Default runtimes for local development and for a plain `bundle exec rake`.
# The Appraisals matrix overrides these to exercise every supported
# ActiveRecord release; see Appraisals and .github/workflows/activerecord.yml.
gem "activerecord", "~> 8.1", require: "active_record"
gem "sqlite3", "~> 2.0"
gem "actionpack", "~> 8.1"
gem "activemodel", "~> 8.1"
gem "railties", "~> 8.1"

gemspec

group :test do
  gem 'database_cleaner-active_record', '~> 2.2'
  gem 'simplecov', require: false
  gem 'test-unit' # Implicitly loaded by ammeter

  gem 'byebug'
  gem 'pry'
  gem 'pry-byebug'
end
