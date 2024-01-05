# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JetsGemLayer::TaskHelper do
  let(:instance) { described_class.new }

  describe 'constants' do
    it 'INPUT_FILES' do
      expect(described_class::INPUT_FILES).to eq ["#{Jets.root}/Gemfile", "#{Jets.root}/Gemfile.lock"]
    end

    it 'OUTPUT_DIR' do
      expect(described_class::OUTPUT_DIR).to eq "#{Jets.root}/tmp/jets_gem_layer"
    end
  end

  describe '.instance' do
    let!(:instance) { described_class.instance }

    before do
      described_class.remove_instance_variable(:@instance)
      allow(described_class).to receive(:new).and_return instance
    end

    it 'returns new instance' do
      expect(described_class.instance).to be instance
      expect(described_class).to have_received(:new)
    end

    it 'memoizes value' do
      expect(described_class.instance).to be instance
      expect(described_class.instance_variable_get(:@instance)).to be instance
      expect(described_class.instance).to be instance
      expect(described_class).to have_received(:new).once
    end
  end

  describe '.install' do
    let(:instance) { described_class.instance }

    before do
      described_class.instance_variable_set(:@installed, nil)
      allow(instance).to receive(:install)
    end

    after do
      Rake::Task.clear
      described_class.instance_variable_set(:@installed, nil)
    end

    it 'delegates to instance' do
      described_class.install
      expect(instance).to have_received(:install).with(no_args)
    end

    it 'only calls through once' do
      described_class.install
      described_class.install
      expect(instance).to have_received(:install).once
    end
  end

  describe '.arn' do
    let(:instance) { described_class.instance }

    before { allow(instance).to receive(:arn).and_return 'arn' }

    it 'returns arn from instance' do
      expect(described_class.arn).to eq 'arn'
      expect(instance).to have_received(:arn).with(no_args)
    end
  end

  describe '#arn' do
    context 'when running in a lambda environment' do
      before { ENV['LAMBDA_TASK_ROOT'] = 'foo' }
      after { ENV['LAMBDA_TASK_ROOT'] = nil }

      it 'returns no-op string, memoizes value' do
        expect(instance.arn).to eq 'no-op-while-running-in-lambda'
        expect(instance.instance_variable_get(:@arn)).to eq 'no-op-while-running-in-lambda'
      end

      context 'when memoized' do
        before { instance.instance_variable_set(:@arn, 'foo') }

        it 'returns memoized value' do
          expect(instance.arn).to eq 'foo'
        end
      end
    end

    context 'when not running in a lambda environement' do
      let(:published_arn) { 'the-published-arn' }

      before do
        allow(instance).to receive(:published_arn).and_return published_arn
      end

      it 'returns arn' do
        expect(instance.arn).to eq 'the-published-arn'
      end

      context 'when published_arn returns nil' do
        let(:published_arn) { nil }

        it 'none found string, memoizes value' do
          expect(instance.arn).to eq 'no-matching-gem-layer-found'
          expect(instance.instance_variable_get(:@arn)).to eq 'no-matching-gem-layer-found'
        end
      end
    end
  end

  describe '#install' do
    let(:loaded_tasks) { Rake::Task.tasks.map(&:to_s) }
    let(:all_tasks) do
      %w[gem_layer:build gem_layer:build_and_publish gem_layer:clean gem_layer:cleanup_published
         gem_layer:delete_all_published gem_layer:publish ]
    end

    it 'loads all the rake tasks' do
      described_class.install
      expect(loaded_tasks).to eq all_tasks
    end
  end

  describe 'invoking tasks' do
    let!(:instance) { described_class.instance }

    before { described_class.install }

    after do
      Rake::Task.clear
      described_class.instance_variable_set(:@installed, nil)
    end

    describe 'build_and_publish' do
      let(:published) { false }

      before do
        allow(instance).to receive(:published?).and_return published
        allow(instance).to receive(:clean_working_dir)
        allow(instance).to receive(:build_layer)
        allow(instance).to receive(:zip_layer)
        allow(instance).to receive(:publish_layer)
      end

      it 'builds, zips, and publishes' do
        Rake::Task['gem_layer:build_and_publish'].invoke
        expect(instance).to have_received(:clean_working_dir)
        expect(instance).to have_received(:build_layer)
        expect(instance).to have_received(:zip_layer)
        expect(instance).to have_received(:publish_layer)
      end

      context 'when already published' do
        let(:published) { true }

        before do
          allow(instance).to receive(:puts)
          allow(instance).to receive_messages(layer_name: 'the-layer', layer_version_description: 'build-hash')
        end

        it 'exits without side effects' do
          Rake::Task['gem_layer:build_and_publish'].invoke
          expect(instance).to have_received(:puts)
            .with 'the-layer already published for build-hash. Not doing anything!'
          expect(instance).not_to have_received(:clean_working_dir)
          expect(instance).not_to have_received(:build_layer)
          expect(instance).not_to have_received(:zip_layer)
          expect(instance).not_to have_received(:publish_layer)
        end
      end
    end

    describe 'build' do
      before do
        allow(instance).to receive(:clean_working_dir)
        allow(instance).to receive(:build_layer)
        allow(instance).to receive(:zip_layer)
      end

      it 'cleans, builds, zips' do
        Rake::Task['gem_layer:build'].invoke
        expect(instance).to have_received(:clean_working_dir)
        expect(instance).to have_received(:build_layer)
        expect(instance).to have_received(:zip_layer)
      end
    end

    describe 'publish' do
      before do
        allow(instance).to receive(:publish_layer)
      end

      it 'publishes' do
        Rake::Task['gem_layer:publish'].invoke
        expect(instance).to have_received(:publish_layer)
      end
    end

    describe 'clean' do
      before do
        allow(instance).to receive(:clean_working_dir)
      end

      it 'cleans' do
        Rake::Task['gem_layer:clean'].invoke
        expect(instance).to have_received(:clean_working_dir)
      end
    end

    describe 'cleanup_published' do
      before do
        allow(instance).to receive(:cleanup_published)
      end

      it 'cleans' do
        Rake::Task['gem_layer:cleanup_published'].invoke
        expect(instance).to have_received(:cleanup_published)
      end
    end

    describe 'delete_all_published' do
      before do
        allow(instance).to receive(:delete_all_published)
      end

      it 'cleans' do
        Rake::Task['gem_layer:delete_all_published'].invoke
        expect(instance).to have_received(:delete_all_published)
      end
    end
  end

  describe '#build_layer' do
    let(:project_namespace) { 'foo_test' }

    before { allow(Jets).to receive(:project_namespace).and_return project_namespace }

    context 'when stubbed' do
      let(:command_return) { true }
      let(:docker_command) do
        %W[docker run --rm
           --platform linux/amd64
           -v #{Jets.root}/tmp/jets_gem_layer/gem_layer_cache:/tmp/inputs
           -v #{Jets.root}/tmp/jets_gem_layer/#{project_namespace}-ruby-3_2_2-gem_layer:/tmp/outputs
           -v #{Jets.root}/lib/jets_gem_layer/build_env:/var/task
           public.ecr.aws/sam/build-ruby3.2 ruby build_layer.rb]
      end

      before do
        allow(FileUtils).to receive(:mkdir_p)
        allow(FileUtils).to receive(:cp)
        allow(instance).to receive(:system).and_return command_return
        allow(instance).to receive(:zip_layer)
      end

      it 'copies correct files, runs docker command' do
        instance.build_layer
        expect(FileUtils).to have_received(:mkdir_p).with("#{Jets.root}/tmp/jets_gem_layer/gem_layer_cache")
        expect(FileUtils).to have_received(:cp).with(["#{Jets.root}/Gemfile", "#{Jets.root}/Gemfile.lock"],
                                                     "#{Jets.root}/tmp/jets_gem_layer/gem_layer_cache")
        expect(instance).to have_received(:system).with(*docker_command)
        expect(instance).to have_received(:zip_layer)
      end

      context 'when GEM_LAYER_ENV is set' do
        let(:docker_command) do
          %W[docker run --rm
             --platform linux/amd64
             -v #{Jets.root}/tmp/jets_gem_layer/gem_layer_cache:/tmp/inputs
             -v #{Jets.root}/tmp/jets_gem_layer/#{project_namespace}-ruby-3_2_2-gem_layer:/tmp/outputs
             -v #{Jets.root}/lib/jets_gem_layer/build_env:/var/task
             -eFIRST_ENV=FOOFOO
             -eSECOND_ENV=BARBAR
             public.ecr.aws/sam/build-ruby3.2 ruby build_layer.rb]
        end

        let(:gem_layer_env) { 'FIRST_ENV=FOOFOO,SECOND_ENV=BARBAR' }

        before do
          allow(ENV).to receive(:key?).and_return false
          allow(ENV).to receive(:key?).with('GEM_LAYER_ENV').and_return true
          allow(ENV).to receive(:fetch).with('GEM_LAYER_ENV').and_return gem_layer_env
        end

        it 'runs docker command with gem layer env added' do
          instance.build_layer
          expect(instance).to have_received(:system).with(*docker_command)
        end
      end

      context 'when GEM_LAYER_PACKAGE_DEPENDENCIES is set' do
        let(:docker_command) do
          %W[docker run --rm
             --platform linux/amd64
             -v #{Jets.root}/tmp/jets_gem_layer/gem_layer_cache:/tmp/inputs
             -v #{Jets.root}/tmp/jets_gem_layer/#{project_namespace}-ruby-3_2_2-gem_layer:/tmp/outputs
             -v #{Jets.root}/lib/jets_gem_layer/build_env:/var/task
             -eGEM_LAYER_PACKAGE_DEPENDENCIES=mysql-devel,something.else
             public.ecr.aws/sam/build-ruby3.2 ruby build_layer.rb]
        end

        let(:package_deps) { 'mysql-devel,something.else' }

        before do
          allow(ENV).to receive(:key?).and_return false
          allow(ENV).to receive(:key?).with('GEM_LAYER_PACKAGE_DEPENDENCIES').and_return true
          allow(ENV).to receive(:fetch).with('GEM_LAYER_PACKAGE_DEPENDENCIES').and_return package_deps
        end

        it 'runs docker command with gem layer env added' do
          instance.build_layer
          expect(instance).to have_received(:system).with(*docker_command)
        end
      end

      context 'when docker command errors' do
        let(:command_return) { false }

        it 'raises RuntimeError' do
          expect { instance.build_layer }.to raise_error RuntimeError
        end
      end
    end

    context 'when integration testing (testing output zip)' do
      let(:zip) { "#{Jets.root}/tmp/jets_gem_layer/#{project_namespace}-ruby-3_2_2-gem_layer.zip" }

      before do
        ENV['GEM_LAYER_PACKAGE_DEPENDENCIES'] = 'mysql-devel'
        instance.build_layer
      end

      after do
        instance.clean_working_dir
        ENV.delete('GEM_LAYER_PACKAGE_DEPENDENCIES')
      end

      it 'creates zip' do
        expect(File.exist?(zip)).to be true
        Zip::File.open(zip) do |zip_file|
          expect(zip_file.glob('lib/*mysql*').first.size).not_to be 0 # check that the mysql2 dependency was brought in
          expect(zip_file.glob('lib/*.so*').first.size).not_to be 0 # check that files exist in lib
          expect(zip_file.glob('ruby/gems/3.2.0/bin/*').first.size).not_to be 0 # check that files exist in gem bin
          expect(zip_file.glob('ruby/gems/3.2.0/extensions/x86_64-linux/3.2.0/json-*/*').first.size).not_to be 0
          expect(zip_file.glob('ruby/gems/3.2.0/gems/jets-*/*').first.size).not_to be 0
          expect(zip_file.glob('ruby/gems/3.2.0/specifications/*').first.size).not_to be 0
        end
      end
    end
  end

  describe '#publish_layer' do
    let(:project_namespace) { 'foo_test' }
    let(:zip) { "#{Jets.root}/tmp/jets_gem_layer/#{project_namespace}-ruby-3_2_2-gem_layer.zip" }
    let(:gemfile) { "#{Jets.root}/Gemfile" }
    let(:gemfile_contents) { 'Gemfile contents' }
    let(:gemfile_lock) { "#{Jets.root}/Gemfile.lock" }
    let(:gemfile_lock_contents) { 'Gemfile.lock contents' }
    let(:aws_client) { instance_double(Aws::Lambda::Client) }
    let(:zip_contents) { 'zip contents' }

    before do
      allow(Jets).to receive(:project_namespace).and_return project_namespace
      allow(File).to receive(:read).with(gemfile).and_return gemfile_contents
      allow(File).to receive(:read).with(gemfile_lock).and_return gemfile_lock_contents
      allow(File).to receive(:read).with(zip).and_return zip_contents
      allow(instance).to receive(:aws_lambda).and_return aws_client
      allow(aws_client).to receive(:publish_layer_version)
      allow(instance).to receive(:puts)
    end

    it 'publishes zip' do
      instance.publish_layer
      expect(aws_client).to have_received(:publish_layer_version).with(
        content: { zip_file: zip_contents },
        description: 'Dependency Hash: 1f2715a8',
        layer_name: 'foo_test-ruby-3_2_2-gem_layer'
      )
    end
  end

  describe '#clean_working_dir' do
    let(:project_namespace) { 'foo_test' }
    let(:working_dir) { "#{Jets.root}/tmp/jets_gem_layer" }
    let(:aws_client) { instance_double(Aws::Lambda::Client) }

    before do
      allow(Jets).to receive(:project_namespace).and_return project_namespace
      allow(FileUtils).to receive(:rm_rf)
    end

    it 'deletes working dir' do
      instance.clean_working_dir
      expect(FileUtils).to have_received(:rm_rf).with(working_dir)
    end
  end

  describe '#cleanup_published' do
    let(:project_namespace) { 'foo_test' }
    let(:first_version) do
      instance_double(Aws::Lambda::Types::LayerVersionsListItem, version: 1, layer_version_arn: 'arn1')
    end
    let(:second_version) do
      instance_double(Aws::Lambda::Types::LayerVersionsListItem, version: 2, layer_version_arn: 'arn2')
    end
    let(:third_version) do
      instance_double(Aws::Lambda::Types::LayerVersionsListItem, version: 3, layer_version_arn: 'arn3')
    end
    let(:versions) { [third_version, second_version, first_version] }
    let(:aws_client) { instance_double(Aws::Lambda::Client) }
    let(:layer_name) { 'foo_test-ruby-3_2_2-gem_layer' }

    before do
      allow(Jets).to receive(:project_namespace).and_return project_namespace
      allow(aws_client).to receive(:delete_layer_version)
      allow(instance).to receive_messages(aws_lambda: aws_client, all_layer_versions: versions)
      allow(instance).to receive(:puts)
    end

    it 'deletes all prior versions based on sort order (keeping only the first returned)' do
      instance.cleanup_published
      expect(aws_client).to have_received(:delete_layer_version).twice
      expect(aws_client).to have_received(:delete_layer_version).with(layer_name:, version_number: 1)
      expect(aws_client).to have_received(:delete_layer_version).with(layer_name:, version_number: 2)
      expect(instance).to have_received(:puts).with 'Deleted arn1'
      expect(instance).to have_received(:puts).with 'Deleted arn2'
      expect(instance).to have_received(:puts).with 'Deleted all prior versions!'
    end
  end

  describe '#delete_all_published' do
    let(:project_namespace) { 'foo_test' }
    let(:first_version) do
      instance_double(Aws::Lambda::Types::LayerVersionsListItem, version: 1, layer_version_arn: 'arn1')
    end
    let(:second_version) do
      instance_double(Aws::Lambda::Types::LayerVersionsListItem, version: 2, layer_version_arn: 'arn2')
    end
    let(:third_version) do
      instance_double(Aws::Lambda::Types::LayerVersionsListItem, version: 3, layer_version_arn: 'arn3')
    end
    let(:versions) { [third_version, second_version, first_version] }
    let(:aws_client) { instance_double(Aws::Lambda::Client) }
    let(:layer_name) { 'foo_test-ruby-3_2_2-gem_layer' }

    before do
      allow(Jets).to receive(:project_namespace).and_return project_namespace
      allow(aws_client).to receive(:delete_layer_version)
      allow(instance).to receive_messages(aws_lambda: aws_client, all_layer_versions: versions)
      allow(instance).to receive(:puts)
    end

    it 'deletes all prior versions based on sort order (keeping only the first returned)' do
      instance.delete_all_published
      expect(aws_client).to have_received(:delete_layer_version).exactly(3).times
      expect(aws_client).to have_received(:delete_layer_version).with(layer_name:, version_number: 1)
      expect(aws_client).to have_received(:delete_layer_version).with(layer_name:, version_number: 2)
      expect(instance).to have_received(:puts).with 'Deleted arn1'
      expect(instance).to have_received(:puts).with 'Deleted arn2'
      expect(instance).to have_received(:puts).with 'Deleted arn3'
      expect(instance).to have_received(:puts).with 'Deleted all published versions!'
    end
  end

  describe '#all_layer_versions' do
    let(:project_namespace) { 'foo_test' }
    let(:first_version) do
      instance_double(Aws::Lambda::Types::LayerVersionsListItem, version: 1, layer_version_arn: 'arn1')
    end
    let(:second_version) do
      instance_double(Aws::Lambda::Types::LayerVersionsListItem, version: 2, layer_version_arn: 'arn2')
    end
    let(:third_version) do
      instance_double(Aws::Lambda::Types::LayerVersionsListItem, version: 3, layer_version_arn: 'arn3')
    end
    let(:versions) { [third_version, second_version, first_version] }
    let(:aws_client) { instance_double(Aws::Lambda::Client) }
    let(:layer_name) { 'foo_test-ruby-3_2_2-gem_layer' }
    let(:first_page) do
      instance_double(Aws::Lambda::Types::ListLayerVersionsResponse,
                      next_marker: 'page2', layer_versions: [third_version, second_version])
    end
    let(:second_page) do
      instance_double(Aws::Lambda::Types::ListLayerVersionsResponse,
                      next_marker: nil, layer_versions: [first_version])
    end

    before do
      allow(Jets).to receive(:project_namespace).and_return project_namespace
      allow(instance).to receive(:aws_lambda).and_return aws_client
      allow(aws_client).to receive(:list_layer_versions).with(layer_name:, max_items: 50, marker: nil)
                                                        .and_return first_page
      allow(aws_client).to receive(:list_layer_versions).with(layer_name:, max_items: 50, marker: 'page2')
                                                        .and_return second_page
    end

    it 'returns all versions from all pages of results' do
      expect(instance.all_layer_versions).to eq versions
    end
  end

  describe '#published_layer_version' do
    let(:project_namespace) { 'foo_test' }
    let(:first_version) do
      instance_double(Aws::Lambda::Types::LayerVersionsListItem, version: 1, layer_version_arn: 'arn1')
    end
    let(:aws_client) { instance_double(Aws::Lambda::Client) }
    let(:layer_name) { 'foo_test-ruby-3_2_2-gem_layer' }
    let(:first_page) { instance_double(Aws::Lambda::Types::ListLayerVersionsResponse, layer_versions: [first_version]) }

    before do
      allow(Jets).to receive(:project_namespace).and_return project_namespace
      allow(instance).to receive(:aws_lambda).and_return aws_client
      allow(aws_client).to receive(:list_layer_versions).with(layer_name:, max_items: 1)
                                                        .and_return first_page
    end

    it 'returns the latest version from the lambda layer, memoizes result' do
      expect(instance.published_layer_version).to be first_version
      expect(instance.instance_variable_get(:@published_layer_version)).to be first_version
      expect(instance.published_layer_version).to be first_version
      expect(aws_client).to have_received(:list_layer_versions).once
    end
  end

  describe '#published?' do
    let(:gemfile) { "#{Jets.root}/Gemfile" }
    let(:gemfile_contents) { 'Gemfile contents' }
    let(:gemfile_lock) { "#{Jets.root}/Gemfile.lock" }
    let(:gemfile_lock_contents) { 'Gemfile.lock contents' }
    let(:published_layer_version) do
      instance_double(Aws::Lambda::Types::LayerVersionsListItem, description: layer_version_description)
    end
    let(:layer_version_description) { 'Dependency Hash: 1f2715a8' }

    before do
      allow(File).to receive(:read).with(gemfile).and_return gemfile_contents
      allow(File).to receive(:read).with(gemfile_lock).and_return gemfile_lock_contents
      allow(instance).to receive(:published_layer_version).and_return published_layer_version
    end

    it 'returns true when matching version exists' do
      expect(instance.published?).to be true
    end

    context 'when published version description does not have a matching file hash' do
      let(:layer_version_description) { 'Dependency Hash: something else' }

      it 'returns false' do
        expect(instance.published?).to be false
      end
    end

    context 'when no published layer' do
      let(:published_layer_version) { nil }

      it 'returns false' do
        expect(instance.published?).to be false
      end
    end
  end

  describe '#published_arn' do
    let(:published) { true }
    let(:published_layer_version) do
      instance_double(Aws::Lambda::Types::LayerVersionsListItem, layer_version_arn: 'the_arn')
    end

    before do
      allow(instance).to receive(:published?).and_return published
    end

    context 'when published' do
      before { allow(instance).to receive(:published_layer_version).and_return published_layer_version }

      it 'returns the arn from the published version' do
        expect(instance.published_arn).to be 'the_arn'
      end
    end

    context 'when not published' do
      let(:published) { false }

      it 'returns nil' do
        expect(instance.published_arn).to be_nil
      end
    end

    context 'when an error occurs (such as with aws client)' do
      before { allow(instance).to receive(:published_layer_version).and_raise StandardError, 'foo' }

      it 'returns error string' do
        expect(instance.published_arn).to eq 'error-fetching-gem-layer-arn'
      end
    end
  end
end
