# frozen_string_literal: true

module JetsGemLayer
  class TaskHelper
    include Rake::DSL
    include Jets::AwsServices

    # Files used to generate the gem layer
    INPUT_FILES = Rake::FileList.new(
      ['Gemfile', 'Gemfile.lock'].collect { |f| File.join(Jets.root, f) }
    )
    LOCAL_TMP_DIR = 'tmp/jets_gem_layer'
    OUTPUT_DIR = File.expand_path(File.join(Jets.root, "#{LOCAL_TMP_DIR}/"))

    def self.install
      new.install
    end

    def self.arn
      @arn ||= new.arn
    end

    def arn
      # We do not want to do any of this when running in the lambda environment
      # as it is only required for deployment.
      @arn ||= if ENV['LAMBDA_TASK_ROOT']
                 'no-op-while-running-in-lambda'
               else
                 published_arn
               end

      @arn ||= 'no-matching-arn-published-to-aws'
    end

    def install
      namespace :gem_layer do
        install_build_and_publish
        install_build
        install_publish
        install_clean
      end
    end

    def install_build_and_publish
      desc 'Build and publish a gem layer version'
      task :build_and_publish do
        Rake::Task['gem_layer:build'].invoke
        Rake::Task['gem_layer:publish'].invoke
        Rake::Task['gem_layer:clean'].invoke
      end
    end

    def install_build
      desc 'Build the gem layer zip file'
      task :build do
        Rake::Task['gem_layer:clean'].invoke
        build_layer
        zip_layer
      end
    end

    def install_publish
      desc 'Publish a built layer zip file'
      task :publish do
        publish_layer
      end
    end

    def install_clean
      desc 'Clean tmp files'
      task :clean do
        FileUtils.rm_r(working_dir) if File.exist?(working_dir)
      end
    end

    def build_layer
      FileUtils.mkdir_p(inputs_dir)
      FileUtils.cp(INPUT_FILES.existing, inputs_dir)
      system(*docker_run_cmd) or raise
    end

    def zip_layer
      pwd = Dir.pwd
      begin
        Dir.chdir(outputs_dir)
        system(*%W[zip -r #{File.join(working_dir, "#{layer_name}.zip")} lib ruby], out: File::NULL) or raise
      ensure
        Dir.chdir(pwd)
      end
    end

    def publish_layer
      aws_lambda.publish_layer_version(
        layer_name:, # required
        description: layer_version_description,
        content: { zip_file: File.read(zip_file_path) }
      )
    end

    private

    def input_hash
      @input_hash ||= begin
        hash = Digest::SHA1.hexdigest(INPUT_FILES.existing.collect do |f|
          File.read(f)
        end.join("\x1C"))
        hash[0..7]
      end
    end

    def inputs_dir
      working_dir('gem_layer_cache')
    end

    def layer_name
      "#{Jets.project_namespace}-ruby-#{RUBY_VERSION.gsub('.', '_')}-gem_layer"
    end

    def layer_version_description
      @layer_version_description ||= "Dependency Hash: #{input_hash}"
    end

    def zip_file_path
      File.join(working_dir, "#{layer_name}.zip")
    end

    def outputs_dir
      working_dir(layer_name.to_s)
    end

    def working_dir(path_suffix = '')
      File.expand_path(
        File.join(
          OUTPUT_DIR,
          path_suffix
        )
      )
    end

    def docker_tag
      (/^\d+\.\d+/.match(RUBY_VERSION)[0]).to_s
    end

    def docker_run_cmd
      cmd = %W[docker run --rm
               --platform linux/amd64
               -v #{inputs_dir}:/tmp/inputs
               -v #{outputs_dir}:/tmp/outputs
               -v #{File.expand_path("#{__dir__}/build_env")}:/var/task]

      ENV.fetch('GEM_LAYER_ENV').split(',').each { |env| cmd.push "-e#{env}" } if ENV['GEM_LAYER_ENV']

      if ENV['GEM_LAYER_PACKAGE_DEPENDENCIES']
        cmd.push "-eGEM_LAYER_PACKAGE_DEPENDENCIES=#{ENV.fetch('GEM_LAYER_PACKAGE_DEPENDENCIES')}"
      end

      cmd.push(*%W[public.ecr.aws/sam/build-ruby#{docker_tag} ruby build_layer.rb])
    end

    def published_arn
      return nil unless published?

      published_layer_version.layer_version_arn
    rescue StandardError
      Jets.logger.error('Could not resolve lambda layer arn')
      'error-fetching-gem-layer-arn'
    end

    def published?
      published_layer_version&.description == layer_version_description
    end

    def published_layer_version
      @published_layer_version ||= aws_lambda.list_layer_versions({ layer_name: }).layer_versions&.first
    end
  end
end
