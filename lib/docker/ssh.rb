module Docker
  class SSH
    require 'sshkit/dsl'
    require 'sshkit'

    attr_reader :user

    def initialize(user)
      @user = user
    end

    def on_hosts(host_names, &block)
      hosts = make_hosts(host_names)
      SSHKit::Coordinator.new(*hosts).each({ in: :sequence, wait: 1 }) do |host|
        if host.local?
          block.call(self)
        else
          as({ user: host.properties.user }) do
            block.call(self)
          end
        end
      end
    end

    def make_hosts(host_names)
      Array(host_names).map do |name|
        host = SSHKit::Host.new(name)
        host.properties.user = user
        host
      end
    end
  end
end
