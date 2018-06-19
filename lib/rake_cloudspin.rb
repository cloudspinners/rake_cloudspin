require 'confidante'
require 'rake_terraform'
require 'rake/tasklib'
# require_relative 'tasklib'
require 'rake_cloudspin/version'
require 'rake_cloudspin/tasklib'
require 'rake_cloudspin/tasks/all'
require 'rake_cloudspin/tasks/base_task'
require 'rake_cloudspin/tasks/stack_task'
require 'rake_cloudspin/tasks/ssh_key_task'
require 'rake_cloudspin/tasks/stack_test_task'

module RakeCloudspin
  def self.define_tasks
    RakeCloudspin::Tasks::All.new
    # RakeCloudspin::Tasks::All.define_tasks
  end
end
