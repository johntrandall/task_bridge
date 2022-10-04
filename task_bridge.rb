#!/usr/bin/env ruby

require "rubygems"
require "bundler/setup"
Bundler.require(:default)
require_relative "lib/omnifocus/service"
require_relative "lib/google_tasks/service"
require_relative "lib/github/service"
require_relative "lib/instapaper/service"
require_relative "lib/reclaim/service"

class TaskBridge
  def initialize
    supported_services = TaskBridge.supported_services
    @options = Optimist.options do
      banner "Sync Tasks from one service to another"
      banner "Supported services: #{supported_services.join(", ")}"
      banner "By default, tasks found with the tags in --tags will have a work context"
      opt :personal_tags, "Tags (or labels) used for personal context", default: ENV.fetch("PERSONAL_TAGS", nil)
      opt :work_tags, "Tags (or labels) used for work context (overrides personal tags)", type: :strings, default: ENV.fetch("WORK_TAGS", nil)
      conflicts :personal_tags, :work_tags
      opt :services, "Services to sync tasks to", default: ENV.fetch("SYNC_SERVICES", "GoogleTasks,Github").split(",")
      # opt :list, "Task list name to sync to", default: ENV.fetch("GOOGLE_TASKS_LIST", "My Tasks")
      opt :delete, "Delete completed tasks on service", default: ["true", "t", "yes", "1"].include?(ENV.fetch("DELETE_COMPLETED", "false").downcase)
      # opt :two_way, "Sync completion state back to task service", default: false
      opt :pretend, "List the found tasks, don't sync", default: false
      opt :verbose, "Verbose output", default: false
      opt :debug, "Print debug output", default: false
      opt :console, "Run live console session", default: false
      opt :testing, "For testing purposes only", default: false
    end
    Optimist.die :services, "Supported services: #{supported_services.join(", ")}" if (supported_services & @options[:services]).empty?
    @options[:uses_personal_tags] = @options[:work_tags].nil?
    # TODO: make changes required to remove the line below
    @primary_service = "Omnifocus::Service".safe_constantize.new(@options)
    @services = @options[:services].map { |s| [s, "#{s}::Service".safe_constantize.new(@options)] }.to_h
  end

  def call
    puts @options.pretty_inspect if @options[:debug]
    return testing if @options[:testing]
    return console if @options[:console]

    @services.each do |service_name, service|
      if @options[:delete]
        service.prune
      else
        service.sync(@services)
      end
    end
  end

  class << self
    def supported_services
      %w[GoogleTasks Github Instapaper Reclaim]
    end
  end

  private

  def console
    binding.pry # rubocop:disable Lint/Debugger
  end

  def render
    @primary_service.tasks_to_sync.each(&:render)
  end

  def testing
    # add code to test here
  end
end

TaskBridge.new.call
