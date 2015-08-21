# Docker Deploy

Deploy and monitor services with [docker-compose](https://docs.docker.com/compose/).

A lot of this is only necessary until docker-compose allows
environment variables to be passed to a docker-compose file.

[https://github.com/docker/compose/issues/1377](https://github.com/docker/compose/issues/1377)

## Usage

Example configuration:

```ruby
Docker::Deploy.configure do |config|
  config.application = 'myapp'
  config.user = 'myappuser'
  config.compose_directory = 'docker'
  config.compose_files = %w(
    docker-compose.deploy.yml
    common.yml
    app_user_settings.env
  )

  config.service(:web) do |service|
    service.stage({ uat: %w(<uat.host>) })
    service.stage({ staging: %w(<staging.host>) })
    service.stage({ production: %w(<prod1.host> <prod2.host>) })

    service.heartbeat = 'public/heartbeat.txt'
    service.load_balancer_delay = 3
    service.boot_time = 3

    service.env_file('deploy.env') do |env|
      [
        "RACK_ENV=#{env.stage}"
      ]
    end

    service.verify = lambda do |remote, config|
      response = remote.capture("curl", "localhost/status")
      json_response = JSON.parse(response)
      json_response["revision"] == config.revision
    end
  end

  config.service(:workers) do |service|
    service.stage({ uat: %w(<uat.host>) })
    service.stage({ staging: %w(<staging.host>) })
    service.stage({ production: %w(<prod-utility.host>) })

    service.boot_time = 3

    service.env_file('deploy.env') do |env|
      [
        "RACK_ENV=#{env.stage}"
      ]
    end
  end
end
```

Note: The first compose file should be the main file that will
be passed to `docker-compose` via the `-f` flag.

Example docker-compose file:

```ruby
web:
  extends:
    file: common.yml
    service: app
  image: library/myorg/myapp:latest
  command: bin/startup.sh
  env_file:
    - app_user_settings.env
    - deploy.env
  ports:
    - 80:9292

workers:
  extends:
    file: common.yml
    service: app
  image: library/myorg/myapp:latest
  command: bundle exec sidekiq -r config/environment.rb
  env_file: deploy.env
```

Note: `<application>:latest` will be replaced with the provided revision when deploying.

The revision will be the current `HEAD`, or environment variables `REVISION`,
`VERSION`, `BRANCH`, `TAG`, `REF`, or `SHA`, in that order.

### CLI

Create a `Deployfile` (probably not a great name) with your config.

Deploy the `web` container to staging:

```bash
$ docker_deploy staging web deploy
```

Deploy all containers to uat:

```bash
$ docker_deploy uat all deploy
```

Start a console in production:

```bash
$ docker_deploy production workers console
```

### Rake or Cap task

Move the configuration to your `Rakefile` or `Capfile`.

```ruby
namespace :deploy do
  namespace :web do
    namesace :staging do
      Docker::Deploy.deploy(:web, :staging)
    end
  end
end
```
