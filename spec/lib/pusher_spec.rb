require 'spec_helper'

describe Push do
  before(:all) do
    Push.config.backend = :test
  end

  context "config" do
    before(:each) do
      @env = Push::Configuration.new
    end
    
    it "should have backend" do
      @env.backend.should eql(:amqp)
    end

    context "amqp" do
      it "should default host to 127.0.0.1" do
        @env.amqp.host.should eql('127.0.0.1')
      end

      it "should default username to guest" do
        @env.amqp.username.should eql('guest')
      end

      it "should default password to guest" do
        @env.amqp.password.should eql('guest')
      end

      it "should default vhost to /" do
        @env.amqp.vhost.should eql('/')
      end

      it "should have queue_ttl" do
        @env.amqp.queue_ttl.should eql(5)
      end
    end

    it "should have logger" do
      @env.logger.should be_instance_of(Logger)
    end
    
    context "web_socket_url" do
      it "should have web_socket_url" do
        @env.web_socket.url.should eql('ws://localhost:3000/_push')
      end
    end

    context "long_poll_url" do
      it "should have long_poll_url" do
        @env.long_poll.url.should eql('http://localhost:3000/_push')
      end

      it "should have long_poll_timeout" do
        @env.long_poll.timeout.should eql(30)
      end
    end

    context "from_hash" do
      before(:each) do
        @env.from_hash({
          'backend' => 'test',
          'web_socket' => {
            'url' => 'ws://push.polleverywhere.com'
          },
          'long_poll' => {
            'url' => 'http://push.polleverywhere.com'
          },
          'amqp' => {
            'host' => 'intra.push.polleverywhere.net',
            'port' => 999,
            'username' => 'brad',
            'password' => 'fun',
            'queue_ttl' => 10,
            'vhost' => 'hi'
          }
        })
      end

      it "should config backend" do
        @env.backend.should eql(:test)
      end
      
      it "should config web_socket url" do
        @env.web_socket.url.should eql('ws://push.polleverywhere.com')
      end
      
      it "should config long_poll url" do
        @env.long_poll.url.should eql('http://push.polleverywhere.com')
      end
      
      context "amqp" do
        it "should config host" do
          @env.amqp.host.should eql('intra.push.polleverywhere.net')
        end

        it "should config username" do
          @env.amqp.username.should eql('brad')
        end

        it "should config password" do
          @env.amqp.password.should eql('fun')
        end

        it "should config vhost" do
          @env.amqp.vhost.should eql('hi')
        end

        it "should config queue_ttl" do
          @env.amqp.queue_ttl.should eql(10)
        end
      end
    end
  end
end