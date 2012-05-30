require 'spec_helper'

describe Firehose::Default do
  it "should have 7474 for default port" do
    Firehose::Default::URI.to_s.should == '//0.0.0.0:7474'
  end
end
