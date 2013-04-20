require 'spec_helper'

describe Firehose do
  it "should have 7474 for default port" do
    Firehose::URI.to_s.should == '//0.0.0.0:7474'
  end
end
