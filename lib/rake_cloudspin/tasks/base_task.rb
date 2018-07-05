
module RakeCloudspin
  module Tasks
    class BaseTask < TaskLib

      parameter :configuration, :required => true
      parameter :stack_name, :required => true
      parameter :stack_type, :required => true

      def stack_config(args = {})
        configuration
          .for_overrides(args)
          .for_scope(stack_type => stack_name)
      end

    end
  end
end
