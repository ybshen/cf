require "spec_helper"
require "webmock/rspec"

describe CF::App::Scale do
  before do
    stub_client_and_precondition
  end

  let(:client) { fake_client :apps => [app] }

  context "when the --disk flag is given" do
    let(:before_value) { 512 }
    let(:app) { fake :app, :disk_quota => before_value }

    subject { cf %W[scale #{app.name} --disk 1G] }

    it "changes the application's disk quota" do
      mock(app).update!
      expect { subject }.to change(app, :disk_quota).from(before_value).to(1024)
    end
  end

  context "when the --memory flag is given" do
    let(:before_value) { 512 }
    let(:app) { fake :app, :memory => before_value }

    subject { cf %W[scale #{app.name} --memory 1G] }

    it "changes the application's memory" do
      mock(app).update!
      expect { subject }.to change(app, :memory).from(before_value).to(1024)
    end

    context "if --restart is true" do
      it "restarts the application" do
        stub(app).update!
        stub(app).started? { true }
        mock_invoke :restart, :app => app
        subject
      end
    end
  end

  context "when the --instances flag is given" do
    let(:before_value) { 3 }
    let(:app) { fake :app, :total_instances => before_value }

    subject { cf %W[scale #{app.name} --instances 5] }

    it "changes the application's number of instances" do
      mock(app).update!
      expect { subject }.to change(app, :total_instances).from(before_value).to(5)
    end
  end
end
