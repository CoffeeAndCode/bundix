require 'json'
require 'open-uri'
require 'shellwords'

# Wraps `nix-prefetch-scripts` to provide consistent output.
module Bundix::Prefetcher::Wrapper
  extend self

  def git(repo, rev, submodules)
    # nix-prefetch-git returns a full sha25 hash
    base16 = exec("HOME=/homeless-shelter nix-prefetch-git #{repo} #{rev} --hash sha256 --leave-dotGit #{"--fetch-submodules" if submodules}")
    assert_length!(base16, 64)
    assert_format!(base16, /^[a-f0-9]+$/)

    # base32-encode for consistency
    base32 = exec("nix-hash --type sha256 --to-base32 #{base16}")
    assert_length!(base32, 52)
    assert_format!(base32, /^[a-z0-9]+$/)

    base32
  end

  # Attempt to use the Rubygems.org API, returning nil if anything goes
  # wrong.
  def gem(name, version)
    version = version.to_s

    begin
      json = open("https://rubygems.org/api/v1/versions/#{name}.json") {|f| f.read}
      gems = JSON.parse(json)

      gem = gems.detect do |g|
        g["number"] == version && g["platform"] == "ruby"
      end

      if gem && gem["sha"]
        # Rubygems.org was _supposed_ to provide base64 encoded SHA-256 hashes,
        # but as of now the hashes are base16 encoded...
        base16 = gem["sha"]
        base32 = exec("nix-hash --type sha256 --to-base32 #{base16.shellescape}")
        assert_length!(base32, 52)
        assert_format!(base32, /^[a-z0-9]+$/)

        base32
      end
    rescue Exception
    end
  end

  def url(url)
    hash = exec("nix-prefetch-url #{url}")

    # nix-prefetch-url returns a base32-encoded sha256 hash
    assert_length!(hash, 52)
    assert_format!(hash, /^[a-z0-9]+$/)

    hash
  end

  def assert_length!(string, expected_length)
    unless string.length == expected_length
      raise "Invalid checksum length; expected #{length}, got #{string.length}"
    end
  end

  def assert_format!(string, regexp)
    unless string =~ regexp
      raise "Invalid checksum format: #{string}"
    end
  end

  def exec(command)
    output = `#{command}`
    raise Thor::Error.new("Prefetch failed: #{command}") unless $?.success?
    output.strip.split("\n").last
  end
end
