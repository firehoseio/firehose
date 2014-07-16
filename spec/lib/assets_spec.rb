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
      env.paths.should include(Firehose::Assets.path('javascripts'))
    end
  end

  describe "Sprockets.javascript" do
    let(:js_spot_checks) do
      [
        "Firehose.Transport",
        "Firehose.version",
        "global.Firehose || (global.Firehose = {})",
        "window.Firehose || (window.Firehose = {})"
      ]
    end
    it "should compile javascript" do
      Firehose::Assets::Sprockets.javascript.should include(*js_spot_checks)
    end
  end
end
