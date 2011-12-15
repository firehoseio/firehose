require 'spec_helper'

def count_instances_of(type)
  count = 0
  ObjectSpace.each_object(Bunny::Exchange) { count += 1 }
  count
end

describe Push::Backend::Bunny do
  before(:all) do
    @consumer = Push::Consumer.new
  end

  it "should be registered as :bunny" do
    Push::Backend::Adapters.backend(:bunny).should be_instance_of(Push::Backend::Bunny)
  end

  it "should be subscribable" do
    Push::Backend::Bunny.new.should be_subscribable
  end

  it "should be publishable" do
    Push::Backend::Bunny.new.should be_publishable
  end

  it "should publish and subscribe to a message" do
    bunny = Push::Backend::Bunny.new

    bunny.publish('the exchange does not exist yet, so I should never be received', '/bunny/1')
    # We need to do this so the queue exists for the producer, and we can receieve a message
    bunny.subscribe(@consumer, '/bunny/1') do |m|
      m.should be_nil
    end
    bunny.publish('testing', '/bunny/1')
    bunny.subscribe(@consumer, '/bunny/1') do |m|
      m.should eql('testing')
    end
  end

  it "should release exchange after publish" do
    lambda do
      1000.times do
        bunny = Push::Backend::Bunny.new
        bunny.publish 'marbles', '/outta/sight'
      end
      GC.start
    end.should change {count_instances_of Bunny::Exchange}.by 1
  end

  it "should release queue after subscribe"
end
