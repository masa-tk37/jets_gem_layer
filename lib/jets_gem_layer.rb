# frozen_string_literal: true

require 'jets'
require 'digest'
require 'fileutils'
require 'rake'

require 'jets_gem_layer/version'
require 'jets_gem_layer/task_helper'

# Base module with helper methods
module JetsGemLayer
  def self.load_tasks
    JetsGemLayer::TaskHelper.install
  end

  def self.arn
    JetsGemLayer::TaskHelper.arn
  end
end
