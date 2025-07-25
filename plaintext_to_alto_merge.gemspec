# frozen_string_literal: true

require_relative "lib/plaintext_to_alto_merge/version"

Gem::Specification.new do |spec|
  spec.name = "plaintext_to_alto_merge"
  spec.version = PlaintextToAltoMerge::VERSION
  spec.authors = ["benwbrum"]
  spec.email = ["ben@benwbrum.com"]

  spec.summary = "Merges corrected plaintext into ALTO XML files, preserving bounding box information"
  spec.description = "A Ruby gem that aligns corrected plaintext transcriptions with raw ALTO XML files, preserving coordinate information while updating text content. Provides both API and command-line interfaces."
  spec.homepage = "https://github.com/benwbrum/plaintext-to-alto-merge"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/benwbrum/plaintext-to-alto-merge"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[.git])
    end
  end
  spec.bindir = "bin"
  spec.executables = ["plaintext-to-alto-merge"]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "nokogiri", "~> 1.0"
  spec.add_dependency "text", "~> 1.0"

  # Development dependencies  
  spec.add_development_dependency "pry-byebug", "~> 3.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
