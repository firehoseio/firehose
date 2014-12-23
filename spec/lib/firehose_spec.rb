require 'spec_helper'

describe Firehose do
  it "has 7474 for default port" do
    expect(Firehose::URI.to_s).to eql('//0.0.0.0:7474')
  end
end
