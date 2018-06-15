require 'rake_cloudspin/version'
require 'rake_cloudspin/tasks/deployment'
require 'rake_cloudspin/tasks/delivery'

module RakeCloudspin
  def self.define_tasks
    RakeCloudspin::Tasks::Delivery.new
    RakeCloudspin::Tasks::Deployment.new
  end
end
