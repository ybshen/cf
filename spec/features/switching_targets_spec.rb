require "spec_helper"

if ENV['CF_V2_RUN_INTEGRATION']
  describe 'A new user tries to use CF against v2 production', :ruby19 => true do

    let(:target) { ENV['CF_V2_TEST_TARGET'] }
    let(:username) { ENV['CF_V2_TEST_USER'] }
    let(:password) { ENV['CF_V2_TEST_PASSWORD'] }
    let(:space) { ENV['CF_V2_TEST_SPACE'] }
    let(:space2) { "#{ENV['CF_V2_TEST_SPACE']}-2"}
    let(:organization) { ENV['CF_V2_TEST_ORGANIZATION'] }
    let(:organization_two) { ENV['CF_V2_TEST_ORGANIZATION_TWO'] }

    let(:created_space_1) { "space-#{rand(10000)}"}
    let(:created_space_2) { "space-#{rand(10000)}"}

    before do
      Interact::Progress::Dots.start!
    end

    after do
      logout
      Interact::Progress::Dots.stop!
    end

    it "can switch targets, even if a target is invalid" do
      BlueShell::Runner.run("#{cf_bin} target invalid-target") do |runner|
        expect(runner).to say "Target refused"
        runner.wait_for_exit
      end

      BlueShell::Runner.run("#{cf_bin} target #{target}") do |runner|
        expect(runner).to say "Setting target"
        expect(runner).to say target
        runner.wait_for_exit
      end
    end

    context "with created spaces in the second org" do
      it "can switch organizations and spaces" do
        login

        BlueShell::Runner.run("#{cf_bin} target -o #{organization_two}") do |runner|
          expect(runner).to say("Switching to organization #{organization_two}")
          expect(runner).to say("Space>")
          runner.send_keys space2

          expect(runner).to say(/Switching to space #{space2}/)

          runner.wait_for_exit
        end

        BlueShell::Runner.run("#{cf_bin} target -s #{space}") do |runner|
          expect(runner).to say("Switching to space #{space}")
          runner.wait_for_exit
        end

        BlueShell::Runner.run("#{cf_bin} target -s #{space2}") do |runner|
          expect(runner).to say("Switching to space #{space2}")
          runner.wait_for_exit
        end
      end
    end
  end
else
  $stderr.puts 'Skipping v2 integration specs; please provide necessary environment variables'
end
