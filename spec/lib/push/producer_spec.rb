require 'spec_helper'

describe Push::Producer do
  before(:all) do
    Push.config.backend = :test
    @producer = Push::Producer.new
  end

  it "should publish" do
    lambda{
      @producer.publish('hi').to('/exchange')
    }.should change(@producer.backend.channels['/exchange'], :count).by(1)
  end
end