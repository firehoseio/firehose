require 'spec_helper'

describe Push::Backend do
  context "adapters" do
    before(:all) do
      @an_adapter = Class.new
    end

    it "register new adapter" do
      lambda{
        Push::Backend::Adapters.register(:super_cool, @an_adapter)
      }.should change(Push::Backend::Adapters.adapters, :count).by(1)
    end

    it "should return instance of an adapter" do
      Push::Backend::Adapters.register(:super_cool, @an_adapter)
      Push::Backend::Adapters.backend(:super_cool).should be_an_instance_of(@an_adapter)
    end
  end
end

describe Push::Backend::Base do
  it "should be subscribable" do
    Push::Backend::Base.new.should be_subscribable
  end

  it "should be publishable" do
    Push::Backend::Base.new.should be_publishable
  end
end
