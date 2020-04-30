require_relative 'lib/hrr_rb_lxns/version'

Gem::Specification.new do |spec|
  spec.name          = "hrr_rb_lxns"
  spec.version       = HrrRbLxns::VERSION
  spec.authors       = ["hirura"]
  spec.email         = ["hirura@gmail.com"]

  spec.summary       = %q{Utilities working with Linux namespaces for CRuby.}
  spec.description   = %q{Utilities working with Linux namespaces for CRuby.}
  spec.homepage      = "https://github.com/hirura/hrr_rb_lxns"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.0.0")

  spec.metadata["homepage_uri"] = spec.homepage
  #spec.metadata["source_code_uri"] = spec.homepage
  #spec.metadata["changelog_uri"] = spec.homepage

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]
  spec.extensions    = ["ext/hrr_rb_lxns/extconf.rb"]

  spec.add_dependency "hrr_rb_mount", ">= 0.3.0"
end
