describe Rory::Application do
  describe ".configure" do
    it 'yields the given block to self' do
      Fixture::Application.configure do |c|
        c.should == Fixture::Application.instance
      end
    end
  end

  describe '.config_path' do
    it 'is set to {root}/config by default' do
      Fixture::Application.config_path.should ==
        Pathname.new(Fixture::Application.root).join('config')
    end

    it 'raises exception if root not set' do
      Rory.application = nil
      class RootlessApp < Rory::Application; end
      expect {
        RootlessApp.config_path
      }.to raise_error(RootlessApp::RootNotConfigured)
      Rory.application = Fixture::Application.instance
    end
  end

  describe ".respond_to?" do
    it 'returns true if the instance said so' do
      Fixture::Application.instance.should_receive(:respond_to?).with(:goat).and_return(true)
      Fixture::Application.respond_to?(:goat).should be_true
    end

    it 'does the usual thing if instance says no' do
      Fixture::Application.instance.should_receive(:respond_to?).twice.and_return(false)
      Fixture::Application.respond_to?(:to_s).should be_true
      Fixture::Application.respond_to?(:obviously_not_a_real_method).should be_false
    end
  end

  describe ".call" do
    it "forwards arg to new dispatcher, and calls dispatch" do
      dispatcher = double(:dispatch => :expected)
      rack_request = double
      Rack::Request.stub(:new).with(:env).and_return(rack_request)
      Rory::Dispatcher.should_receive(:new).with(rack_request, Fixture::Application.instance).and_return(dispatcher)
      Fixture::Application.call(:env).should == :expected
    end
  end

  describe ".load_config_data" do
    it "returns parsed yaml file with given name from directory at config_path" do
      Fixture::Application.any_instance.stub(:config_path).and_return('Africa the Great')
      YAML.stub(:load_file).with(
        File.expand_path(File.join('Africa the Great', 'foo_type.yml'))).
        and_return(:oscar_the_grouch_takes_a_nap)
      Fixture::Application.load_config_data(:foo_type).should == :oscar_the_grouch_takes_a_nap
    end
  end

  describe ".connect_db" do
    it "sets up sequel connection to DB from YAML file" do
      config = { 'development' => :expected }
      Fixture::Application.any_instance.stub(:load_config_data).with(:database).and_return(config)
      Sequel.should_receive(:connect).with(:expected).and_return(double(:loggers => []))
      Fixture::Application.connect_db('development')
    end
  end

  describe ".routes" do
    it "generates a collection of routing objects from route configuration" do
      expect(Fixture::Application.routes).to eq [
        Rory::Route.new('foo/:id/bar', :to => 'foo#bar', :methods => [:get, :post]),
        Rory::Route.new('this/:path/is/:very_awesome', :to => 'awesome#rad'),
        Rory::Route.new('lumpies/:lump', :to => 'lumpies#show', :methods => [:get], :module => 'goose'),
        Rory::Route.new('rabbits/:chew', :to => 'rabbits#chew', :methods => [:get], :module => 'goose/wombat'),
        Rory::Route.new('', :to => 'root#vegetable', :methods => [:get]),
        Rory::Route.new('', :to => 'root#no_vegetable', :methods => [:delete]),
        Rory::Route.new('for_reals/:parbles', :to => 'for_reals#srsly', :methods => [:get])
      ]
    end
  end

  describe ".spin_up" do
    it "connects the database" do
      Rory::Application.any_instance.should_receive(:connect_db)
      Rory::Application.spin_up
    end
  end

  describe '.auto_require_paths' do
    after(:each) do
      Fixture::Application.instance.instance_variable_set(:@auto_require_paths, nil)
    end

    it 'includes models, controllers, and helpers by default' do
      Fixture::Application.auto_require_paths.should == ['models', 'controllers', 'helpers']
    end

    it 'accepts new paths' do
      Fixture::Application.auto_require_paths << 'chocolates'
      Fixture::Application.auto_require_paths.should == ['models', 'controllers', 'helpers', 'chocolates']
    end
  end

  describe '.require_all_files' do
    it 'requires all files in auto_require_paths' do
      Fixture::Application.any_instance.stub(:auto_require_paths).and_return(['goats', 'rhubarbs'])
      [:goats, :rhubarbs].each do |folder|
        Rory::Support.should_receive(:require_all_files_in_directory).
          with(Pathname.new(Fixture::Application.root).join("#{folder}"))
      end
      Fixture::Application.require_all_files
    end
  end

  describe '.use_middleware' do
    it 'adds the given middleware to the stack, retaining args and block' do
      require Fixture::Application.root.join('lib', 'dummy_middleware')
      Fixture::Application.use_middleware DummyMiddleware, :puppy do |dm|
        dm.prefix = 'a salubrious'
      end

      expect(Fixture::Application.instance).to receive(:dispatcher).
        and_return(dispatch_stack_mock = double)
      expect(dispatch_stack_mock).to receive(:call).
        with('a salubrious puppy')
      Fixture::Application.call({})
      Fixture::Application.middleware.clear
    end
  end
end
