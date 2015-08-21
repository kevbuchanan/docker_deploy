require 'docker/ssh'

module Docker
  class Remote
    def initialize(service, stage, config)
      @service = service
      @stage = stage
      @config = config
    end

    NO_RAISE = { raise_on_non_zero_exit: false }

    def deploy(hosts = remote_hosts)
      hosts.each do |host|
        stop(host)
        start(host)
      end
    end

    def start(hosts = remote_hosts)
      sync_files(hosts)
      ssh.on_hosts(hosts) do |remote|
        unless remote.execute("docker-compose #{compose_options} pull #{name}", NO_RAISE)
          remote.fatal("Image for revision #{revision} not found")
          fail
        end
        remote.execute("docker-compose #{compose_options} up --no-deps -d #{name}")
        remote.execute("docker exec #{container_name} /bin/bash -c \"echo #{revision} > REVISION\"")
        sleep(boot_time)
        unless service.verify.call(remote, config)
          remote.fatal("Verification failed")
          fail
        end
        if heartbeat
          remote.execute("docker exec #{container_name} touch #{heartbeat}", NO_RAISE)
        end
      end
    end

    def stop(hosts = remote_hosts)
      ssh.on_hosts(hosts) do |remote|
        if heartbeat
          remote.execute("docker exec #{container_name} rm #{heartbeat}", NO_RAISE)
          sleep(load_balancer_delay)
        end
        remote.execute("docker-compose #{compose_options} stop #{name}", NO_RAISE)
        remote.execute("docker-compose #{compose_options} rm -f #{name}", NO_RAISE)
      end
    end

    def console(hosts = remote_hosts)
      ssh.on_hosts(hosts.first) do |remote|
        command = "docker exec -it #{container_name} bash"
        exec("ssh #{config.user}@#{remote_hosts.first} -t '#{command}'")
      end
    end

    private

    attr_reader :service, :stage, :config

    def sync_files(hosts = remote_hosts)
      ssh.on_hosts(:local) do |local|
        remote_hosts.each do |host|
          compose_files.each do |file|
            local.execute("sed 's/#{application}:latest/#{application}:#{revision}/' #{config.compose_directory}/#{file} > /tmp/#{file}")
            local.execute("rsync /tmp/#{file} #{config.user}@#{host}:#{compose_file_path(file)}")
            local.execute("rm /tmp/#{file}")
          end
        end
      end
    end

    def container_name
      "#{application.gsub('_', '')}_#{name}_1"
    end

    def ssh
      @ssh ||= SSH.new(config.user)
    end

    def name
      service.name
    end

    def application
      config.application
    end

    def revision
      config.revision
    end

    def remote_hosts
      service.stages[stage]
    end

    def load_balancer_delay
      service.load_balancer_delay
    end

    def boot_time
      service.boot_time
    end

    def heartbeat
      service.heartbeat
    end

    def compose_options
      @compose_options ||= (
        [
          "-f #{compose_file_path(config.compose_files.first)}",
          "-p #{application}"
        ].join(' ')
      )
    end

    def compose_files
      @compose_files ||= (
        service.env_files.each do |name, block|
          values = block.call(env)
          File.open("#{config.compose_directory}/#{name}", 'w+') { |f| f.write(values.join('\n')) }
        end
        config.compose_files + service.env_files.keys
      )
    end

    def compose_file_path(file)
      "/tmp/#{application}/#{file}"
    end

    Env = Struct.new(:application, :stage, :hosts)

    def env
      @env ||= Env.new(application, stage, remote_hosts)
    end
  end
end
