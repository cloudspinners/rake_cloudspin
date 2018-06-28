
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

      def stack_manager_role_arn
        if assume_role?
          "arn:aws:iam::#{stack_config.aws_account_id}:role/stack_manager-#{stack_config.component}-#{stack_config.estate}"
        else
          raise "Don't use 'stack_manager_role_arn' if assume_role? is false"
        end
      end

      def assume_role?
        stack_config.assume_role == true
      end

    end
  end
end
