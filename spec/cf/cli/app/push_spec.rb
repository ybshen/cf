require 'spec_helper'
require "cf/cli/app/push"

describe CF::App::Push do
  let(:global) { { :color => false, :quiet => true } }
  let(:inputs) { {} }
  let(:given) { {} }
  let(:path) { "somepath" }
  let(:client) { fake_client }
  let(:push) { CF::App::Push.new(Mothership.commands[:push]) }

  before do
    any_instance_of(CF::CLI) do |cli|
      stub(cli).client { client }
      stub(cli).precondition { nil }
    end
  end

  describe 'metadata' do
    let(:command) { Mothership.commands[:push] }

    describe 'command' do
      subject { command }
      its(:description) { should eq "Push an application, syncing changes if it exists" }
      it { expect(Mothership::Help.group(:apps, :manage)).to include(subject) }
    end

    include_examples 'inputs must have descriptions'

    describe 'arguments' do
      subject { command.arguments }
      it 'has the correct argument order' do
        should eq([{ :type => :optional, :value => nil, :name => :name }])
      end
    end
  end

  describe '#sync_app' do
    let(:app) { fake(:app) }

    before do
      stub(app).upload
      app.changes = {}
    end

    subject do
      push.input = Mothership::Inputs.new(nil, push, inputs, {}, global)
      push.sync_app(app, path)
    end

    shared_examples 'common tests for inputs' do |*args|
      context 'when the new input is the same as the old' do
        type, input = args
        input ||= type

        let(:inputs) { {input => old} }

        it "does not update the app's #{type}" do
          dont_allow(push).line
          dont_allow(app).update!
          expect { subject }.not_to change { app.send(type) }
        end
      end
    end

    it 'triggers the :push_app filter' do
      mock(push).filter(:push_app, app) { app }
      subject
    end

    it 'uploads the app' do
      mock(app).upload(path)
      subject
    end

    context 'when no inputs are given' do
      let(:inputs) { {} }

      it 'should not update the app' do
        dont_allow(app).update!
        subject
      end

      it "should not set memory on the app" do
        dont_allow(app).__send__(:memory=)
        subject
      end
    end

    context 'when memory is given' do
      let(:old) { 1024 }
      let(:new) { "2G" }
      let(:app) { fake(:app, :memory => old) }
      let(:inputs) { { :memory => new } }

      it 'updates the app memory, converting to megabytes' do
        stub(push).line(anything)
        mock(app).update!
        expect { subject }.to change { app.memory }.from(old).to(2048)
      end

      it 'outputs the changed memory in human readable sizes' do
        mock(push).line("Changes:")
        mock(push).line("memory: 1G -> 2G")
        stub(app).update!
        subject
      end

      include_examples 'common tests for inputs', :memory
    end

    context 'when instances is given' do
      let(:old) { 1 }
      let(:new) { 2 }
      let(:app) { fake(:app, :total_instances => old) }
      let(:inputs) { { :instances => new } }

      it 'updates the app instances' do
        stub(push).line(anything)
        mock(app).update!
        expect { subject }.to change { app.total_instances }.from(old).to(new)
      end

      it 'outputs the changed instances' do
        mock(push).line("Changes:")
        mock(push).line("total_instances: 1 -> 2")
        stub(app).update!
        subject
      end

      include_examples 'common tests for inputs', :total_instances, :instances
    end

    context 'when command is given' do
      let(:old) { "./start" }
      let(:new) { "./start foo " }
      let(:app) { fake(:app, :command => old) }
      let(:inputs) { { :command => new } }

      it 'updates the app command' do
        stub(push).line(anything)
        mock(app).update!
        expect { subject }.to change { app.command }.from("./start").to("./start foo ")
      end

      it 'outputs the changed command in single quotes' do
        mock(push).line("Changes:")
        mock(push).line("command: './start' -> './start foo '")
        stub(app).update!
        subject
      end

      include_examples 'common tests for inputs', :command
    end

    context 'when restart is given' do
      let(:inputs) { { :restart => true, :memory => 4096 } }


      context 'when the app is already started' do
        let(:app) { fake(:app, :state => "STARTED") }

        it 'invokes the restart command' do
          stub(push).line
          mock(app).update!
          mock(push).invoke(:restart, :app => app)
          subject
        end

        context 'but there are no changes' do
          let(:inputs) { { :restart => true } }

          it 'invokes the restart command' do
            stub(push).line
            dont_allow(app).update!
            mock(push).invoke(:restart, :app => app)
            subject
          end
        end
      end

      context 'when the app is not already started' do
        let(:app) { fake(:app, :state => "STOPPED") }

        it 'does not invoke the restart command' do
          stub(push).line
          mock(app).update!
          dont_allow(push).invoke(:restart, :app => app)
          subject
        end
      end
    end

    context "when buildpack is given" do
      let(:old) { nil }
      let(:app) { fake(:app, :buildpack => old) }
      let(:inputs) { { :buildpack => new } }

      context "and it's an invalid URL" do
        let(:new) { "git@github.com:foo/bar.git" }

        before do
          stub(app).update! do
            raise CFoundry::MessageParseError.new(
              "Request invalid due to parse error: Field: buildpack, Error: Value git@github.com:cloudfoundry/heroku-buildpack-ruby.git doesn't match regexp String /GIT_URL_REGEX/",
              1001)
          end
        end

        it "fails and prints a pretty message" do
          stub(push).line(anything)
          expect { subject }.to raise_error(
            CF::UserError, "Buildpack must be a public git repository URI.")
        end
      end

      context "and it's a valid URL" do
        let(:new) { "git://github.com/foo/bar.git" }

        it "updates the app's buildpack" do
          stub(push).line(anything)
          mock(app).update!
          expect { subject }.to change { app.buildpack }.from(old).to(new)
        end

        it "outputs the changed buildpack with single quotes" do
          mock(push).line("Changes:")
          mock(push).line("buildpack: '' -> '#{new}'")
          stub(app).update!
          subject
        end

        include_examples 'common tests for inputs', :buildpack
      end
    end
  end

  describe '#setup_new_app (integration spec!!)' do
    let(:app) { fake(:app, :guid => nil) }
    let(:host) { "" }
    let(:domain) { fake(:domain, :name => "example.com") }
    let(:inputs) do
      { :name => "some-app",
        :instances => 2,
        :memory => 1024,
        :host => host,
        :domain => domain
      }
    end
    let(:global) { {:quiet => true, :color => false, :force => true} }

    before do
      stub(client).app { app }
    end

    subject do
      push.input = Mothership::Inputs.new(Mothership.commands[:push], push, inputs, global, global)
      push.setup_new_app(path)
    end

    it 'creates the app' do
      mock(app).create!
      mock(app).upload(path)
      mock(push).filter(:create_app, app) { app }
      mock(push).filter(:push_app, app) { app }
      mock(push).invoke :map, :app => app, :host => host, :domain => domain
      mock(push).invoke :start, :app => app
      subject
    end
  end
end
