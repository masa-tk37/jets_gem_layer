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

      @arn ||= 'no-matching-gem-layer-found'
    end

    def install
      namespace :gem_layer do
        install_build_and_publish
        install_build
        install_publish
        install_clean
        install_cleanup_published
        install_delete_all_published
      end
    end

    def install_build_and_publish
      desc 'Build and publish a gem layer version, if necessary'
      task :build_and_publish do
        if published?
          puts "#{layer_name} already published for #{layer_version_description}. Not doing anything!"
          break
        end
        Rake::Task['gem_layer:build'].invoke
        Rake::Task['gem_layer:publish'].invoke
        Rake::Task['gem_layer:clean'].invoke
      end
    end

    def install_build
      desc 'Build a gem layer zip file'
      task :build do
        Rake::Task['gem_layer:clean'].invoke
        build_layer
        zip_layer
      end
    end

    def install_publish
      desc 'Publish the already built layer zip file'
      task :publish do
        publish_layer
      end
    end

    def install_clean
      desc 'Clean jets_gem_layer tmp files'
      task :clean do
        FileUtils.rm_r(working_dir) if File.exist?(working_dir)
      end
    end

    def install_cleanup_published
      desc 'Delete old layer versions from AWS (for use after deployment)'
      task :cleanup_published do
        cleanup_published
      end
    end

    def install_delete_all_published
      desc 'Delete all published versions of the gem layer from AWS'
      task :delete_all_published do
        delete_all_published
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
        puts 'Layer zipped successfully!'
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
      puts "#{layer_name} published for #{layer_version_description}!"
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
      @published_layer_version ||= aws_lambda.list_layer_versions(layer_name:, max_items: 1).layer_versions.first
    end

    # paginate through all layer versions to get them all (but it's unlikely there will be more than 1 page)
    def all_layer_versions
      all_versions = []
      marker = nil
      loop do
        page = aws_lambda.list_layer_versions(layer_name:, max_items: 50, marker:)
        all_versions.concat page.layer_versions
        marker = page.next_marker
        break if marker.nil?
      end
      all_versions
    end

    def cleanup_published
      all_layer_versions.each_with_index do |layer_version, i|
        next if i.zero? # skips the current version

        aws_lambda.delete_layer_version(layer_name:, version_number: layer_version.version)
        puts "Deleted #{layer_version.layer_version_arn}"
      end
      puts 'Deleted all prior versions!'
    end

    def delete_all_published
      all_layer_versions.each do |layer_version|
        aws_lambda.delete_layer_version(layer_name:, version_number: layer_version.version)
        puts "Deleted #{layer_version.layer_version_arn}"
      end
      puts 'Deleted all published versions!'
    end
  end
end
