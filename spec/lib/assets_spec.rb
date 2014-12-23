require 'spec_helper'
require 'sprockets'

describe Firehose::Assets do
  describe ".path" do
    it "has root path" do
      expect(Firehose::Assets.path('poop')).to eql(File.expand_path('../../../lib/assets/poop', __FILE__))
    end

    it "accepts folders" do
      expect(Firehose::Assets.path('poop')).to eql(File.join(Firehose::Assets.path, 'poop'))
    end
  end

  describe "Sprockets.configure" do
    it "configures environment" do
      env = Firehose::Assets::Sprockets.configure Sprockets::Environment.new
      expect(env.paths).to include(Firehose::Assets.path('javascripts'))
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
    it "compiles javascript" do
      expect(Firehose::Assets::Sprockets.javascript).to include(*js_spot_checks)
    end
  end
end
