require 'rake_cloudspin/version'
require 'rake_cloudspin/tasks/deployment'

module RakeCloudspin
  def self.define_tasks
    RakeCloudspin::Tasks::Deployment.new
  end
end
