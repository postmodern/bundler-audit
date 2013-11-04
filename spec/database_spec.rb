require 'spec_helper'
require 'bundler/audit/database'
require 'tmpdir'

describe Bundler::Audit::Database do
  describe "path" do
    subject { described_class.path }

    it "it should be a directory" do
      File.directory?(subject).should be_true
    end

    it "should prefer the user repo, iff it's as up to date, or more up to date than the vendored one" do
      Bundler::Audit::Database.update!

      # As up to date...
      expect(Bundler::Audit::Database.path).to eq mocked_user_path

      # More up to date...
      fake_a_commit_in_the_user_repo
      expect(Bundler::Audit::Database.path).to eq mocked_user_path

      roll_user_repo_back(2)
      expect(Bundler::Audit::Database.path).to eq Bundler::Audit::Database::VENDORED_PATH
    end
  end

  describe "update!" do
    it "should create the USER_PATH path as needed" do
      Bundler::Audit::Database.update!
      expect(File.directory?(mocked_user_path)).to be true
    end

    it "should create the repo, then update it given multple successive calls." do
      expect_update_to_clone_repo!
      Bundler::Audit::Database.update!
      expect(File.directory?(mocked_user_path)).to be true

      expect_update_to_update_repo!
      Bundler::Audit::Database.update!
      expect(File.directory?(mocked_user_path)).to be true
    end
  end

  describe "#initialize" do
    context "when given no arguments" do
      subject { described_class.new }

      it "should default path to path" do
        subject.path.should == described_class.path
      end
    end

    context "when given a directory" do
      let(:path ) { Dir.tmpdir }

      subject { described_class.new(path) }

      it "should set #path" do
        subject.path.should == path
      end
    end

    context "when given an invalid directory" do
      it "should raise an ArgumentError" do
        lambda {
          described_class.new('/foo/bar/baz')
        }.should raise_error(ArgumentError)
      end
    end
  end

  describe "#check_gem" do
    let(:gem) do
      Gem::Specification.new do |s|
        s.name    = 'actionpack'
        s.version = '3.1.9'
      end
    end

    context "when given a block" do
      it "should yield every advisory effecting the gem" do
        advisories = []

        subject.check_gem(gem) do |advisory|
          advisories << advisory
        end

        advisories.should_not be_empty
        advisories.all? { |advisory|
          advisory.kind_of?(Bundler::Audit::Advisory)
        }.should be_true
      end
    end

    context "when given no block" do
      it "should return an Enumerator" do
        subject.check_gem(gem).should be_kind_of(Enumerable)
      end
    end
  end

  describe "#size" do
    it { subject.size.should > 0 }
  end

  describe "#to_s" do
    it "should return the Database path" do
      subject.to_s.should == subject.path
    end
  end
end
