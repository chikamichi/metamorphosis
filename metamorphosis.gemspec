# -*- encoding: utf-8 -*-
require './lib/metamorphosis/version'

Gem::Specification.new do |s|
  s.name = %q{metamorphosis}
  s.version = Metamorphosis::VERSION
  s.author = "Jean-Denis Vauguet <jd@vauguet.fr>"
  s.description = %q{Metamorphosis is a generic plugins system. Using Metamorphosis, a module or a class is able to alter and/or extend its original behavior at will.}
  s.email = %q{jd@vauguet.fr}
  s.files = Dir["lib/**/*"] + Dir["vendor/**/*"] + Dir["spec/**/*"] + ["Gemfile", "LICENSE", "Rakefile", "README.md"]
  s.homepage = %q{http://github.com/chikamichi/metamorphosis}
  s.summary = %q{A generic plugin system. Let's do some differentiation!}
  s.add_dependency "configliere"
  s.add_dependency "facets"
  s.add_dependency "activesupport"
  s.add_development_dependency "yard"
end

