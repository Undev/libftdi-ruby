# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "ftdi/version"

Gem::Specification.new do |s|
  s.name        = "libftdi-ruby"
  s.version     = Ftdi::VERSION.dup
  s.authors     = ["Akzhan Abdulin"]
  s.email       = ["akzhan.abdulin@gmail.com"]
  s.homepage    = "http://github.com/akzhan/libftdi-ruby"
  s.summary     = %q{libftdi library binding}
  s.description = %q{libftdi library binding to talk to FTDI chips}

  s.rubyforge_project = "libftdi-ruby"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "ffi", "~> 1.0"
end

