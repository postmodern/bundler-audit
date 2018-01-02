#
# Copyright (c) 2013-2016 Hal Brodigan (postmodern.mod3 at gmail.com)
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

require 'bundler/audit/scanner'
require 'bundler/audit/version'

require 'thor'
require 'bundler'
require 'bundler/vendored_thor'
require 'json'

module Bundler
  module Audit
    class CLI < ::Thor

      default_task :check
      map '--version' => :version

      desc 'check', 'Checks the Gemfile.lock for insecure dependencies'
      method_option :quiet, :type => :boolean, :aliases => '-q'
      method_option :verbose, :type => :boolean, :aliases => '-v'
      method_option :json, :type => :boolean, :aliases => '-j'
      method_option :ignore, :type => :array, :aliases => '-i'
      method_option :update, :type => :boolean, :aliases => '-u'

      def check
        update if options[:update]

        scanner    = Scanner.new
        vulnerable = false

        insec_srcs = []
        insec_gems = {}
        insec_gems[:technologies] = []
        scanner.scan(:ignore => options.ignore) do |result|
          vulnerable = true

          case result
            when Scanner::InsecureSource
              if not options.json? then
                print_warning "Insecure Source URI found: #{result.source}"
              else
                insec_srcs.push(result.source)
              end
            when Scanner::UnpatchedGem
              if not options.json? then
                print_advisory result.gem, result.advisory
              else
                insec_gems[:technologies].push(:name => result.gem.name, :version => result.gem.version, :issues => [:name => (result.advisory.cve ? ("CVE-" + result.advisory.cve) : ("OSVDB-" + result.advisory.osvdb.to_s)), :short_desc => result.advisory.title, :description => result.advisory.description, :risk => (result.advisory.criticality ? result.advisory.criticality : "unknown")])
              end
          end
          end
          if options.json? and insec_srcs.length >= 1 then
            is = {}
            is[:insecure_sources] = insec_srcs
            puts is.to_json
          end
          if options.json? and not insec_gems.empty? then
            puts insec_gems.to_json
          end

          if vulnerable
            say "Vulnerabilities found!", :red unless options.json?
            exit 1
          else
            say("No vulnerabilities found", :green) unless options.quiet? || unless options.json?
          end
        end
      end

      desc 'update', 'Updates the ruby-advisory-db'
      method_option :quiet, :type => :boolean, :aliases => '-q'

      def update
        say("Updating ruby-advisory-db ...") unless options.quiet?

        case Database.update!(quiet: options.quiet?)
        when true
          say("Updated ruby-advisory-db", :green) unless options.quiet?
        when false
          say "Failed updating ruby-advisory-db!", :red
          exit 1
        when nil
          say "Skipping update", :yellow
        end

        unless options.quiet?
          puts("ruby-advisory-db: #{Database.new.size} advisories")
        end
      end

      desc 'version', 'Prints the bundler-audit version'
      def version
        database = Database.new

        puts "#{File.basename($0)} #{VERSION} (advisories: #{database.size})"
      end

      protected

      def say(message="", color=nil)
        color = nil unless $stdout.tty?
        super(message.to_s, color)
      end

      def print_warning(message)
        say message, :yellow
      end

      def print_advisory(gem, advisory)
        say "Name: ", :red
        say gem.name

        say "Version: ", :red
        say gem.version

        say "Advisory: ", :red

        if advisory.cve
          say "CVE-#{advisory.cve}"
        elsif advisory.osvdb
          say advisory.osvdb
        end

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

    end
  end
end
