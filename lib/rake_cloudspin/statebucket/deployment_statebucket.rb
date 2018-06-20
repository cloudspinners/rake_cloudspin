
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
  end
end
