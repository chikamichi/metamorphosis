require 'rubygems'
require 'rake'
require 'yard'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "metamorphosis"
    gem.summary = %Q{A generic plugin system. Let's do some differentiation!}
    gem.description = %Q{Metamorphosis is a generic plugins system. Using Metamorphosis, a module or a class is able to alter and/or extend its original behavior at will.}
    gem.email = "jd@vauguet.fr"
    gem.homepage = "http://github.com/chikamichi/metamorphosis"
    gem.authors = ["Jean-Denis Vauguet"]
    gem.add_dependency "configliere", ">= 0.0.5"
    gem.add_dependency "activesupport"
    #gem.add_development_dependency "thoughtbot-shoulda", ">= 0"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
#require 'hanna/rdoctask' # http://github.com/mislav/hanna
require 'sdoc'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.main = "README.md"
  rdoc.rdoc_dir = 'doc'
  rdoc.title = "metamorphosis #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.options << '--webcvs=http://github.com/chikamichi/metamorphosis/tree/master/'
  rdoc.options << '--line-numbers' << '--inline-source' # sdoc mandatory options
  rdoc.template = 'direct' # lighter template used on railsapi.com
end

YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb', 'README.md', 'TODO', 'LICENSE', 'VERSION']
  #t.options = ['--any', '--extra', '--opts'] # optional
end
