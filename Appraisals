# Supported ActiveRecord releases.
# Keep in sync with the matrix in .github/workflows/activerecord.yml.
#
# The `sqlite3` constraint follows what each ActiveRecord release supports:
# 7.1 ships `gem "sqlite3", "~> 1.4"` in its adapter, 7.2 and later accept 2.x.
%w[7.1 7.2 8.0 8.1].each do |version|
  sqlite = version.to_f < 7.2 ? "~> 1.4" : "~> 2.0"

  appraise "activerecord-#{version}" do
    gem "sqlite3", sqlite, :platform => "ruby"
    gem "activerecord", "~> #{version}.0", :require => "active_record"

    # Ammeter dependencies:
    gem "actionpack", "~> #{version}.0"
    gem "activemodel", "~> #{version}.0"
    gem "railties", "~> #{version}.0"
  end
end

# Mongoid support is best effort: the adapter is kept as-is and exercised
# against the current Mongoid release, but it is not part of the required
# compatibility matrix. Mongoid < 8 is not installable on Ruby >= 3.2 because
# of its bson_ext dependency, so those appraisals have been dropped.
#
# ActiveRecord has to be removed explicitly, otherwise rspec-rails wires its
# fixture support into every example group and the generator specs fail with
# ActiveRecord::ConnectionNotDefined: no database connection is established on
# a Mongoid run.
appraise 'mongoid-9' do
  gem "mongoid", "~> 9.1"

  remove_gem "activerecord"
  remove_gem "sqlite3"
end
