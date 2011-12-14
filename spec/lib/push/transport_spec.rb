require 'spec_helper'

describe Push::Transport::Dispatcher do
  context "when initializing with non-default config settings" do
    before(:all) do
      @dispatcher = Push::Transport::Dispatcher.new do |config|
        config.timeout  = 4
        config.consumer = Proc.new {|env| Push::Consumer.new(env['HTTP_FOO'])}
        config.channel  = Proc.new {|env| env['HTTP_BAR']}
      end
    end

    context "config" do
      before(:each) do
        @config = @dispatcher.configuration
      end
      
      it "should have the non-default timeout" do
        @config.timeout.should equal 4
      end

      it "should use request's HTTP_FOO for consumer ID"
      it "should use request's HTTP_BAR for channel"
    end
  end
  
  context "when initializing without specifying config settings" do
    before(:all) do
      @dispatcher = Push::Transport::Dispatcher.new
    end
    
    it "should use the defaults..."
  end
end
