require 'spec_helper'
require 'integrations/shared_examples'

describe "rainbows" do
  def server; :rainbows; end # Let isn't allowed in before(:all)
  it_behaves_like 'Firehose::Rack::App'
end
