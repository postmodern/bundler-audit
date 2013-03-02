#
# Copyright (c) 2013 Hal Brodigan (postmodern.mod3 at gmail.com)
#
# bundler-audit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# bundler-audit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with bundler-audit.  If not, see <http://www.gnu.org/licenses/>.
#

require 'bundler/audit/database'
require 'bundler/audit/version'

require 'bundler/vendored_thor'
require 'bundler'

module Bundler
  module Audit
    class CLI < Thor

      default_task :check
      map '--version' => :version

      desc 'check', 'Checks the Gemfile.lock for insecure dependencies'
      method_option :verbose, :type => :boolean, :aliases => '-v'

      def check
        check_rubygems_version

        database    = Database.new
        vulnerable  = false
        lock_file   = load_gemfile_lock('Gemfile.lock')

        lock_file.specs.each do |gem|
          database.check_gem(gem) do |advisory|
            vulnerable = true
            print_advisory gem, advisory
          end
        end

        if vulnerable
          say "Unpatched versions found!", :red
          exit 1
        else
          say "No unpatched versions found", :green
        end
      end

      desc 'version', 'Prints the bundler-audit version'
      def version
        database = Database.new

        puts "#{File.basename($0)} #{VERSION} (advisories: #{database.size})"
      end

      protected

      def load_gemfile_lock(path)
        Bundler::LockfileParser.new(File.read(path))
      end

      def print_advisory(gem, advisory)
        say "Name: ", :red
        say gem.name

        say "Version: ", :red
        say gem.version

        say "CVE: ", :red
        say advisory.cve

        say "Criticality: ", :red
        case advisory.criticality
        when :low    then say "Low"
        when :medium then say "Medium", :yellow
        when :high   then say "High", [:red, :bold]
        else              say "Unknown"
        end

        say "URL: ", :red
        say advisory.url

        if options.verbose?
          say "Description:", :red
          say

          print_wrapped advisory.description, :indent => 2
          say
        else

          say "Title: ", :red
          say advisory.title
        end

        unless advisory.patched_versions.empty?
          say "Solution: upgrade to ", :red
          say advisory.patched_versions.join(', ')
        else
          say "Solution: ", :red
          say "remove or disable this gem until a patch is available!", [:red, :bold]
        end

        say
      end

      def say(string="", color=nil)
        color = nil unless $stdout.tty?
        super(string, color)
      end

      def check_rubygems_version
        major, minor, *_ = Gem::VERSION.split('.')
        if major.to_i <= 1 and minor.to_i < 8
          say "Warning: RubyGems version (#{Gem::VERSION}) is too old and may give " \
            "false positives in results. >= 1.8 recommended.", :red
          say
        end
      end

    end
  end
end
