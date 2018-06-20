
module RakeCloudspin
  module Statebucket

    def self.build_bucket_name(estate:, deployment_identifier:, component:)
      [
        'state',
        estate,
        deployment_identifier,
        component
      ].join('-')
    end

    # class DeploymentStatebucket

    #   attr_reader :bucket_name, :region, :terraform_config, :state_key

    #   def initialize(configuration)
    #     estate = configuration['estate']
    #     component = configuration['component']
    #     deployment_identifier = configuration['deployment_identifier']

    #     @bucket_name = [
    #         'state',
    #         configuration['estate'],
    #         configuration['component'],
    #         'deployment',
    #         configuration['deployment_identifier']
    #     ].join('-')

    #     @region = configuration['region']
    #     @terraform_config = {
    #       'region' => @region,
    #       'bucket' => @bucket_name,
    #       'key' => @state_key,
    #       'encrypt' => 'true'
    #     }
    #   end
    # end

  end
end
