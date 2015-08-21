lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name        = "docker_deploy"
  spec.version     = "0.0.1"
  spec.authors     = ["Kevin Buchanan"]
  spec.email       = ["kevaustinbuch@gmail.com"]
  spec.summary     = "Deploy/Manage/Monitor remote services with Docker"
  spec.files       = `git ls-files -z`.split("\x0")
  spec.executables = %w(docker_deploy)

  spec.add_dependency 'sshkit', '~> 1.3'
end
