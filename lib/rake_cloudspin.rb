require 'rake_cloudspin/version'
require 'rake_cloudspin/tasks/deployment_stack_tasks'
require 'rake_cloudspin/tasks/delivery_stack_tasks'

module RakeCloudspin
  def self.define_tasks
    RakeCloudspin::Tasks::DeliveryStackTasks.new
    RakeCloudspin::Tasks::DeploymentStackTasks.new
  end
end
