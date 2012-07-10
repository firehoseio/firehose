require 'spec_helper'
require 'sprockets'

describe Firehose::Assets do
  describe ".path" do
    it "should have root path" do
      Firehose::Assets.path('poop').should == File.expand_path('../../../lib/assets/poop', __FILE__)
    end

    it "should accept folders" do
      Firehose::Assets.path('poop').should == File.join(Firehose::Assets.path, 'poop')
    end
  end

  describe "Sprockets.configure" do
    it "should configure environment" do
      env = Firehose::Assets::Sprockets.configure Sprockets::Environment.new
      env.paths.should include(Firehose::Assets.path('flash'),  Firehose::Assets.path('javascripts'))
    end
  end
end