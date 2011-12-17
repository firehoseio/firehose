require 'spec_helper'

describe Push::Transport::Dispatcher do
  context "when initializing with non-default config settings" do
    before(:all) do
      @dispatcher = Push::Transport::Dispatcher.new do |config|
        config.timeout  = 4
        config.consumer = Proc.new {|env| Push::Consumer.new(env['HTTP_FOO'])}
        config.channel  = Proc.new {|env| env['HTTP_BAR']}
        config.verbose_logging = 'true-ish'
      end
    end

    context "config" do
      before(:each) do
        @config = @dispatcher.configuration
      end
      
      it "should have the non-default timeout" do
        @config.timeout.should equal 4
      end
      
      it "should be set for verbose logging" do
        @config.verbose_logging.should be_true
      end

      it "should use request's HTTP_FOO for consumer ID" do
        consumer = @config.consumer 'HTTP_FOO' => 'abc123'
        consumer.id.should == 'abc123'
      end
      
      it "should use request's HTTP_BAR for channel" do
        channel = @config.channel 'HTTP_BAR' => '/XY/Z'
        channel.should == '/XY/Z'
      end
    end
  end
  
  context "when initializing without specifying config settings" do
    before(:all) do
      @dispatcher = Push::Transport::Dispatcher.new
    end
    
    context "config" do
      before(:each) do
        @config = @dispatcher.configuration
      end
      
      it "should use the defaults..." do
        @config.timeout.should equal 30
        @config.verbose_logging.should be_false

        consumer = @config.consumer 'HTTP_CONSUMER_ID' => 'sammiches'
        consumer.id.should == 'sammiches'

        channel = @config.channel 'PATH_INFO' => '/xxx/zz'
        channel.should == '/xxx/zz'
      end
    end
  end
  
end
