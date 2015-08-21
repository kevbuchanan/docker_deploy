require 'docker/remote'

module Docker
  module Deploy
    class Config
      attr_accessor(
        :application,
        :user,
        :compose_files,
        :compose_directory,
        :services
      )

      def initialize
        @services = {}
        @files = []
      end

      def service(name)
        new_service = ServiceConfig.new(name)
        @services[name] = new_service
        yield new_service
        new_service
      end

      REFS = %w(REVISION VERSION BRANCH TAG REF SHA)

      def revision
        @revision ||= (
          ref = REFS.reduce(nil) { |x, y| x || ENV[y] }
          `git rev-parse #{ref || "HEAD"}`.chomp
        )
      end

      class ServiceConfig
        attr_reader :name
        attr_accessor(
          :heartbeat,
          :boot_time,
          :load_balancer_delay,
          :stages,
          :env_files,
          :verify
        )

        def initialize(name)
          @name = name
          @stages = {}
          @env_files = {}
          @verify = lambda { |r, c| true }
        end

        def stage(stage_mapping)
          @stages.merge!(stage_mapping)
        end

        def env_file(name, &block)
          @env_files[name] = block
        end
      end
    end

    def self.config
      @config
    end

    def self.configure
      @config = Config.new
      yield config
      config
    end

    def self.deploy(service_name, stage)
      perform(service_name, stage, :deploy)
    end

    def self.start(service_name, stage)
      perform(service_name, stage, :start)
    end

    def self.stop(service_name, stage)
      perform(service_name, stage, :stop)
    end

    def self.console(service_name, stage)
      perform(service_name, stage, :console)
    end

    def self.perform(service_name, stage, command)
      if service_name == :all
        config.services.each do |_, service|
          Remote.new(service, stage, config).send(command)
        end
      else
        service = config.services[service_name]
        Remote.new(service, stage, config).send(command)
      end
    end
  end
end
