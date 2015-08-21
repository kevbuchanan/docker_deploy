require 'docker/deploy'

module Docker
  class CLI
    def self.run(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv
    end

    def run
      load "Deployfile"
      Deploy.send(@argv[2], @argv[1].to_sym, @argv[0].to_sym)
    end
  end
end
