require 'spec_helper'
require 'integrations/shared_examples'

describe "rainbows" do
  let(:server) { :rainbows }
  it_behaves_like 'Firehose::Rack::App'
end
