require 'spec_helper'

describe "CLI" do
  include Helpers

  let(:executable) do
    File.expand_path(File.join(File.dirname(__FILE__),'..','bin','bundle-audit'))
  end

  context "when auditing a vulnerable bundle" do
    let(:bundle)    { 'vuln' }
    let(:directory) { File.join('spec','bundle',bundle) }

    subject do
      Dir.chdir(directory) { sh(executable, :fail => true) }
    end

    it "should print a warning" do
      subject.should include("Unpatched versions found!")
    end

    it "should print advisory information for the vulnerable gems" do
      subject.should include(%{
Name: actionpack
Version: 3.2.10
CVE: 2013-0156
Criticality: High
URL: http://osvdb.org/show/osvdb/89026
Title: Ruby on Rails params_parser.rb Action Pack Type Casting Parameter Parsing Remote Code Execution
Solution: upgrade to ~> 2.3.15, ~> 3.0.19, ~> 3.1.10, >= 3.2.11

Name: activerecord
Version: 3.2.10
CVE: 2013-0276
Criticality: Medium
URL: http://direct.osvdb.org/show/osvdb/90072
Title: Ruby on Rails Active Record attr_protected Method Bypass
Solution: upgrade to ~> 2.3.17, ~> 3.1.11, >= 3.2.12

Name: activerecord
Version: 3.2.10
CVE: 2013-0155
Criticality: High
URL: http://osvdb.org/show/osvdb/89025
Title: Ruby on Rails Active Record JSON Parameter Parsing Query Bypass
Solution: upgrade to ~> 2.3.16, ~> 3.0.19, ~> 3.1.10, >= 3.2.11
      }.strip)
    end

    context "when ignoring warnings" do
      it "still prints warnings that are not ignored" do
        out = Dir.chdir(directory) { sh("#{executable} --safe 2013-0155@3.2.10", :fail => true) }
        out.should include "CVE: 2013-0276"
        out.should_not include "CVE: 2013-0155"
      end

      it "prints no warnings if all warnings are ignored" do
        out = Dir.chdir(directory) { sh("#{executable} --safe 2013-0155@3.2.10 2013-0276@3.2.10 2013-0156@3.2.10") }
        out.strip.should == "No unpatched versions found"
      end
    end
  end

  context "when auditing a secure bundle" do
    let(:bundle)    { 'secure' }
    let(:directory) { File.join('spec','bundle',bundle) }

    subject do
      Dir.chdir(directory) { sh(executable) }
    end

    it "should print nothing when everything is fine" do
      subject.strip.should == "No unpatched versions found"
    end
  end
end
