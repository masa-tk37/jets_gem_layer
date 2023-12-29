# Jets Gem Layer
This gem provides Rake tasks to create and publish an AWS Lambda Layer from project gems and
their linked libraries. Designed for use with Ruby on Jets 5 as part of your deployment, as an
alternative to Jets Pro.

This gem creates a Lambda Layer based on your Jets project namespace and ruby version. I.e. for the app `demo` in `production` environment, 
the Lambda Layer `demo-prod-ruby-3-2-2-gem_layer` will be created or its version incremented as needed. A new version is published when
Gemfile.lock and/or Gemfile is changed (which is tracked based on a hash added to the Lambda Layer version description).

* The gem's build task runs in a docker container, i.e. `public.ecr.aws/sam/build-ruby:3.2`. The container version
is based on the current minor ruby version (i.e. 3.2 for ruby 3.2.2, so ensure your build environment's ruby version
is correctly set for your project.
* Docker is a prerequisite and must be installed to use this gem.
* This gem has not been tested to work on windows machines

## Installation

1. Jets pro should be disabled, as multiple layers with project dependencies would be duplicative.

```ruby
# config/application.rb

config.pro.disable = true
```

2. The layer ARN created by this gem must be inserted so it is referenced on app deployment. The easiest way to do this
is to add it to your environment configuration.

```ruby
# config/production.rb

# JetsGemLayer.arn will resolve to the latest version of the published Layer, also looking for a correct hash in the
# layer description indicating the current Gemfile.lock and Gemfile are supported.
# If a suitable layer is not found, the gem will log an error and resolve to 'error-fetching-gem-layer-arn' which will allow your
# application to run locally but ensure `jets deploy` will fail if attempted prior to publishing the gem layer
config.lambda.layers = [JetsGemLayer.arn]
```

3. Add this gem to your Gemfile:
```ruby
# Gemfile
gem 'jets_gem_layer'
```

4. Add the gem's initializer to your Rakefile
```ruby
# Rakefile

require 'jets'
require 'jets_gem_layer'
require_relative 'config/application'

Jets.application.load_tasks
JetsGemLayer.load_tasks
```

3. After running `bundle install`, run `rake -T` and you should see this Gem's tasks available for use.
```
➜ rake -T
rake gem_layer:build_and_publish   # Build, publish, and clean
rake gem_layer:build               # Build the gem layer zip file
rake gem_layer:publish             # Publish the built gem laye zip to AWS
rake gem_layer:clean               # Clean up the gem's tmp files
```

## Configuration

The following environmental variables may be used::
* `GEM_LAYER_ENV`: Comma-separated `key=value` pairs which will be added to the docker build environment.
For example, to pass a Gemfury token for Bundler, you could use `GEM_LAYER_ENV="BUNDLE_GEM__FURY__IO=xxyyzz"`
and `BUNDLE_GEM__FURY__IO` will be set correctly within the build container.
* `GEM_LAYER_PACKAGE_DEPENDENCIES`: use this to identify comma separated dependencies required for bundle install
specific to your Gemfile. For example, to build the `mysql2` gem you will need to set `GEM_LAYER_PACKAGE_DEPENDENCIES=mysql-devel`.
Dependencies will be installed within the build container and copied into the published Lambda Layer.

## Deployment
Within your project directory (example for development environment):
1. run `JETS_ENV=development rake gem_layer:build_and_publish`
2. run `JETS_ENV=development rake jets deploy`

## Acknowledgements
A big thank you to the authors of [Lambda Layer Cake](https://github.com/loganb/lambda-layer-cake), which served as a reference.