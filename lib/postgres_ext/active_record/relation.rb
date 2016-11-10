gdep_4_2 = Gem::Dependency.new('activerecord', '>= 4.2.0')
ar_4_2_version_cutoff = gdep_4_2.matching_specs.sort_by(&:version).last

gdep_5_0 = Gem::Dependency.new('activerecord', '~> 5.0.0')
ar_5_0_version_cutoff = gdep_5_0.matching_specs.sort_by(&:version).last

require 'postgres_ext/active_record/relation/merger'
require 'postgres_ext/active_record/relation/query_methods'

if ar_5_0_version_cutoff
  require 'postgres_ext/active_record/5.0/relation/predicate_builder/array_handler'
elsif ar_4_2_version_cutoff
  require 'postgres_ext/active_record/relation/predicate_builder/array_handler'
else
  require 'postgres_ext/active_record/4.x/relation/predicate_builder'
end
