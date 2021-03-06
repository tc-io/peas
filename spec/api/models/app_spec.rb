require 'spec_helper'

describe App do
  let(:app) { Fabricate :app }

  describe 'deploy()' do
    include_context :docker_creation_mock

    before :each do
      allow_any_instance_of(App).to receive(:build).and_return(true) # Prevent building
      allow(Sidekiq::Status).to receive(:status).and_return(:complete) # Build completes instantly
    end

    it 'should trigger a build' do
      allow_any_instance_of(App).to receive(:scale) # Prevent scaling
      expect_any_instance_of(App).to receive(:build)
      Sidekiq::Testing.inline! do
        app.deploy
      end
    end

    it 'should scale web process to 1 if there are no existing containers for the app' do
      expect_any_instance_of(App).to receive(:scale).with({'web' => 1}, 'deploy')
      Sidekiq::Testing.inline! do
        app.deploy
      end
    end

    it "should broadcast the app's URI for a custom domain" do
      Fabricate :setting, key: 'domain', value: 'custom-domain.com'
      allow_any_instance_of(App).to receive(:scale) # Prevent scaling
      expect_any_instance_of(App).to receive(:broadcast).with(no_args)
      expect_any_instance_of(App).to receive(:broadcast).with(
        /       Deployed to http:\/\/#{app.name}\.custom-domain\.com/
      )
      expect_any_instance_of(App).to receive(:broadcast).with(no_args)
      Sidekiq::Testing.inline! do
        app.deploy
      end
    end

    it "should rescale processes to the app's existing scaling profile" do
      allow_any_instance_of(App).to receive(:scale) # Prevent scaling
      3.times { Fabricate :pea, app: app, process_type: 'web' }
      2.times { Fabricate :pea, app: app, process_type: 'worker' }
      expect_any_instance_of(App).to receive(:scale).with(
        { 'web' => 3, 'worker' => 2 }, 'deploy'
      )
      Sidekiq::Testing.inline! do
        app.deploy
      end
    end
  end

  describe 'build()' do
    # Doesn't use :docker_creation_mock

    before :each do
      stub_const "Peas::TMP_REPOS", '/tmp/peas/test/repos'
      stub_const "Peas::TMP_TARS", '/tmp/peas/test/tars'
      FileUtils.rm_rf '/tmp/peas/test/'
    end

    context 'Fetching and tarring an app for Buildstep' do
      before :each do
        allow(app).to receive(:sh)
      end
      it 'should create the necessary directories' do
        app._fetch_and_tar_repo
        expect(File.exist? Peas::TMP_REPOS).to eq true
        expect(File.exist? Peas::TMP_TARS).to eq true
      end
      it "should clone the app when the repo doesn't exist locally" do
        expect(app).to receive(:sh).with(%r(git clone .* #{Peas::TMP_REPOS}/#{app.name}))
        app._fetch_and_tar_repo
      end
      it 'should only pull updates when the repo already exists locally' do
        FileUtils.mkdir_p "#{Peas::TMP_REPOS}/fabricated"
        expect(app).to receive(:sh).with(%r(cd #{Peas::TMP_REPOS}/#{app.name} .* git pull))
        app._fetch_and_tar_repo
      end
    end

    context 'The build process itself' do

      it 'should build an app resulting in a new Docker image', :docker do
        # Use the nodejs example just because it builds so quickly
        app = Fabricate :app, remote: 'git@github.com:heroku/node-js-sample.git', name: 'node-js-sample'
        allow(app).to receive(:_fetch_and_tar_repo) # Comment out when recording
        allow(app).to receive(:broadcast)
        expect(app).to receive(:broadcast).with(/       Node.js app detected/)
        expect(app).to receive(:broadcast).with(/-----> Installing dependencies/)
        expect(app).to receive(:broadcast).with(/       Procfile declares types -> web/)
        expect_any_instance_of(Docker::Container).to receive(:commit)
        expect_any_instance_of(Docker::Container).to receive(:delete)
        app.build
      end

      it 'should deal with a failed build', :docker do
        app = Fabricate :app,
          remote: 'git@github.com:saddleback/hello-world-cpp.git',
          name: 'hello-world-cpp'
        allow(app).to receive(:_fetch_and_tar_repo) # Comment out when recording
        allow(app).to receive(:broadcast)
        expect_any_instance_of(Docker::Container).to_not receive(:commit)
        expect_any_instance_of(Docker::Container).to receive(:delete)
        expect {
          app.build
        }.to raise_error RuntimeError, /Unable to select a buildpack/
      end
    end
  end

  describe 'scale()' do
    include_context :docker_creation_mock

    it 'should create peas' do
      app.scale({web: 3, worker: 2})
      expect(Pea.where(app: app).where(process_type: 'web').count).to eq 3
      expect(Pea.where(app: app).where(process_type: 'worker').count).to eq 2
    end
  end

end
