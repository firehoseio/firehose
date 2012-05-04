require 'spec_helper'

describe Firehose::Broker do
  include EM::TestHelper

  let(:broker)  { Firehose::Broker.new }

  it "should unsubscibe consumers and remove them from the collection" do
    stats = nil

    em do
      broker.consumer('1').subscribe_to('/the-channel')
      broker.consumer('2').subscribe_to('/the-channel')
      broker.consumer('2').subscribe_to('/a-channel')

      em.add_timer(1) do
        stats = broker.stats
        broker.stop
        em.stop
      end
    end

    stats.should == {
      '1' => {'subscriptions' => ['/the-channel'] },
      '2' => {'subscriptions' => ['/the-channel', '/a-channel']}
    }

    broker.stats.should == {}
  end
end