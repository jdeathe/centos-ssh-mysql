centos-ssh-mysql
================

Docker Image of CentOS-6 6.8 x86_64, MySQL 5.1.

Includes Automated password generation and an option for custom initialisation SQL. Supports custom configuration via environment variables.

## Overview & links

The latest CentOS-6 based release can be pulled from the centos-6 Docker tag. For a specific release tag the convention is `centos-6-1.7.0` for the [1.7.0](https://github.com/jdeathe/centos-ssh-mysql/tree/1.7.0) release tag.

- centos-6 [(centos-6/Dockerfile)](https://github.com/jdeathe/centos-ssh-mysql/blob/centos-6/Dockerfile)

The Dockerfile can be used to build a base image that is the bases for several other docker images.

Included in the build are the [EPEL](http://fedoraproject.org/wiki/EPEL) and [IUS](https://ius.io/) repositories. Installed packages include [OpenSSH](http://www.openssh.com/portable.html) secure shell, [vim-minimal](http://www.vim.org/), [MySQL Server and client programs](http://www.mysql.com) are installed along with python-setuptools, [supervisor](http://supervisord.org/) and [supervisor-stdout](https://github.com/coderanger/supervisor-stdout).

Supervisor is used to start the mysqld server daemon when a docker container based on this image is run. To enable simple viewing of stdout for the service's subprocess, supervisor-stdout is included. This allows you to see output from the supervisord controlled subprocesses with `docker logs {container-name}`.

If enabling and configuring SSH access, it is by public key authentication and, by default, the [Vagrant](http://www.vagrantup.com/) [insecure private key](https://github.com/mitchellh/vagrant/blob/master/keys/vagrant) is required.

### SSH Alternatives

SSH is not required in order to access a terminal for the running container. The simplest method is to use the docker exec command to run bash (or sh) as follows:

```
$ docker exec -it {container-name-or-id} bash
```

For cases where access to docker exec is not possible the preferred method is to use Command Keys and the nsenter command. See [command-keys.md](https://github.com/jdeathe/centos-ssh-mysql/blob/centos-6/command-keys.md) for details on how to set this up.

## Quick Example

Run up a container named `mysql.pool-1.1.1` from the docker image `jdeathe/centos-ssh-mysql` on port 3306 of your docker host.

```
$ docker run -d \
  --name mysql.pool-1.1.1 \
  -p 3306:3306 \
  -v /var/lib/mysql \
  jdeathe/centos-ssh-mysql:centos-6
```

Now you can verify it is initialised and running successfully by inspecting the container's logs.

```
$ docker logs mysql.pool-1.1.1
```

If it is the first run there should be additional output showing the initialisation SQL that was run and the root user's password.

![Docker Logs MySQL Bootstrap](https://raw.github.com/jdeathe/centos-ssh-mysql/centos-6/images/docker-logs-mysql-bootstrap.png)

The MySQL table data is persistent across container restarts by setting the MySQL data directory `/var/lib/mysql` as a data volume. We didn't specify a name or docker_host path so Docker will give it a unique name and store it in `/var/lib/docker/volumes/`; to find out where the data is stored on the Docker host you can use `docker inspect`.

```
$ docker inspect \
  --format '{{ json (index .Mounts 0).Source }}' \
  mysql.pool-1.1.1
```

To access the MySQL SQL shell run the following:

```
$ docker exec -it mysql.pool-1.1.1 mysql -p -u root
```

To import the Sakila example database from the [MySQL Documentation](https://dev.mysql.com/doc/index-other.html) and view the first 2 records from the film table.

```
$ export MYSQL_ROOT_PASSWORD={your-password}

$ docker exec -i mysql.pool-1.1.1 \
  mysql -p${MYSQL_ROOT_PASSWORD} -u root \
  <<< $(tar -xzOf /dev/stdin \
    <<< $(curl -sS http://downloads.mysql.com/docs/sakila-db.tar.gz) \
    sakila-db/sakila-schema.sql \
  )

$ docker exec -i mysql.pool-1.1.1 \
  mysql -p${MYSQL_ROOT_PASSWORD} -u root \
  <<< $(tar -xzOf /dev/stdin \
    <<< $(curl -sS http://downloads.mysql.com/docs/sakila-db.tar.gz) \
    sakila-db/sakila-data.sql \
  )

$ docker exec -it  mysql.pool-1.1.1 \
  mysql -p${MYSQL_ROOT_PASSWORD} -u root \
  -e "SELECT * FROM sakila.film LIMIT 2 \G;"
```

## Instructions

### Running

To run the a docker container from this image you can use the standard docker commands. Alternatively, you can use the embedded (Service Container Manager Interface) [scmi](https://github.com/jdeathe/centos-ssh-mysql/blob/centos-6/usr/sbin/scmi) that is included in the image since `centos-6-1.7.0` or, if you have a checkout of the [source repository](https://github.com/jdeathe/centos-ssh-mysql), and have make installed the Makefile provides targets to build, install, start, stop etc. where environment variables can be used to configure the container options and set custom docker run parameters.

#### SCMI Installation Examples

The following example uses docker to run the SCMI install command to create and start a container named `mysql.pool-1.1.1`. To use SCMI it requires the use of the `--privileged` docker run parameter and the docker host's root directory mounted as a volume with the container's mount directory also being set in the `scmi` `--chroot` option. The `--setopt` option is used to add extra parameters to the default docker run command template; in the following example a named configuration volume is added which allows the SSH host keys to persist after the first container initialisation. Not that the placeholder `{{NAME}}` can be used in this option and is replaced with the container's name.

*Note:* In most cases you will want to create an initial database, database user, (optionally a static password), and define the user's network access. If you don't define these settings using the appropriate environment variables on first run, the settings will not be parsed by the bootstrap initialisation process and only local root access will be available. To re-initialise a container that uses a named data volume mapped to /var/lib/mysql terminate the container and the data volume to allow it to be recreated.

##### SCMI Install

```
$ docker run \
  --rm \
  --privileged \
  --volume /:/media/root \
  jdeathe/centos-ssh-mysql:centos-6-1.7.0 \
  /sbin/scmi install \
    --chroot=/media/root \
    --tag=centos-6-1.7.0 \
    --name=mysql.pool-1.1.1 \
    --setopt='--volume {{NAME}}.data-mysql:/var/lib/mysql'
```

#### SCMI Uninstall

To uninstall the previous example simply run the same docker run command with the scmi `uninstall` command.

```
$ docker run \
  --rm \
  --privileged \
  --volume /:/media/root \
  jdeathe/centos-ssh-mysql:centos-6-1.7.0 \
  /sbin/scmi uninstall \
    --chroot=/media/root \
    --tag=centos-6-1.7.0 \
    --name=mysql.pool-1.1.1 \
    --setopt='--volume {{NAME}}.data-mysql:/var/lib/mysql'
```

#### SCMI Systemd Support

If your docker host has systemd (and optionally etcd) installed then `scmi` provides a method to install the container as a systemd service unit. This provides some additional features for managing a group of instances on a single docker host and has the option to use an etcd backed service registry. Using a systemd unit file allows the System Administrator to use a Drop-In to override the settings of a unit-file template used to create service instances. To use the systemd method of installation use the `-m` or `--manager` option of `scmi` and to include the optional etcd register companion unit use the `--register` option.

```
$ docker run \
  --rm \
  --privileged \
  --volume /:/media/root \
  jdeathe/centos-ssh-mysql:centos-6-1.7.0 \
  /sbin/scmi install \
    --chroot=/media/root \
    --tag=centos-6-1.7.0 \
    --name=mysql.pool-1.1.1 \
    --manager=systemd \
    --register \
    --env='MYSQL_SUBNET="0.0.0.0/0.0.0.0"' \
    --env='MYSQL_USER="app-user"' \
    --env='MYSQL_USER_PASSWORD="Passw0rd"' \
    --env='MYSQL_USER_DATABASE="app-db"' \
    --setopt='--volume {{NAME}}.data-mysql:/var/lib/mysql'
```

#### SCMI Fleet Support

If your docker host has systemd, fleetd (and optionally etcd) installed then `scmi` provides a method to schedule the container  to run on the cluster. This provides some additional features for managing a group of instances on a [fleet](https://github.com/coreos/fleet) cluster and has the option to use an etcd backed service registry. To use the fleet method of installation use the `-m` or `--manager` option of `scmi` and to include the optional etcd register companion unit use the `--register` option.

##### SCMI Image Information

Since release `centos-6-1.7.0` the install template has been added to the image metadata. Using docker inspect you can access `scmi` to simplify install/uninstall tasks.

To see detailed information about the image run `scmi` with the `--info` option. To see all available `scmi` options run with the `--help` option.

```
$ eval "sudo -E $(
    docker inspect \
    -f "{{.ContainerConfig.Labels.install}}" \
    jdeathe/centos-ssh-mysql:centos-6-1.7.0
  ) --info"
```

To perform an installation using the docker name `mysql.pool-1.2.1` simply use the `--name` or `-n` option.

```
$ eval "sudo -E $(
    docker inspect \
    -f "{{.ContainerConfig.Labels.install}}" \
    jdeathe/centos-ssh-mysql:centos-6-1.7.0
  ) --name=mysql.pool-1.2.1"
```

To uninstall use the *same command* that was used to install but with the `uninstall` Label.

```
$ eval "sudo -E $(
    docker inspect \
    -f "{{.ContainerConfig.Labels.uninstall}}" \
    jdeathe/centos-ssh-mysql:centos-6-1.7.0
  ) --name=mysql.pool-1.2.1"
```

##### SCMI on Atomic Host

With the addition of install/uninstall image labels it is possible to use [Project Atomic's](http://www.projectatomic.io/) `atomic install` command to simplify install/uninstall tasks on [CentOS Atomic](https://wiki.centos.org/SpecialInterestGroup/Atomic) Hosts.

To see detailed information about the image run `scmi` with the `--info` option. To see all available `scmi` options run with the `--help` option.

```
$ sudo -E atomic install \
  -n mysql.pool-1.3.1 \
  jdeathe/centos-ssh-mysql:centos-6-1.7.0 \
  --info
```

To perform an installation using the docker name `mysql.pool-1.3.1` simply use the `-n` option of the `atomic install` command.

```
$ sudo -E atomic install \
  -n mysql.pool-1.3.1 \
  jdeathe/centos-ssh-mysql:centos-6-1.7.0
```

Alternatively, you could use the `scmi` options `--name` or `-n` for naming the container.

```
$ sudo -E atomic install \
  jdeathe/centos-ssh-mysql:centos-6-1.7.0 \
  --name mysql.pool-1.3.1
```

To uninstall use the *same command* that was used to install but with the `uninstall` Label.

```
$ sudo -E atomic uninstall \
  -n mysql.pool-1.3.1 \
  jdeathe/centos-ssh-mysql:centos-6-1.7.0
```

#### Using environment variables

The following example sets up a custom MySQL database, user and user password on first run. This will only work when MySQL runs the initialisation process and values must be specified for MYSQL_USER and MYSQL_USER_DATABASE. If MYSQL_USER_PASSWORD is not specified or left empty a random password will be generated.

*Note:* Settings applied by environment variables will override those set within configuration volumes from release 1.3.1. Existing installations that use the mysql-bootstrap.conf saved on a configuration "data" volume will not allow override by the environment variables. Also users can update mysql-bootstrap.conf to prevent the value being replaced by that set using the environment variable.

```
$ docker stop mysql.pool-1.1.1 && \
  docker rm mysql.pool-1.1.1

$ docker run -d \
  --name mysql.pool-1.1.1 \
  -p 3306:3306 \
  --env "MYSQL_SUBNET=0.0.0.0/0.0.0.0" \
  --env "MYSQL_USER=app-user" \
  --env "MYSQL_USER_PASSWORD=" \
  --env "MYSQL_USER_DATABASE=app-db" \
  -v mysql.pool-1.1.1.data-mysql:/var/lib/mysql \
  jdeathe/centos-ssh-mysql:centos-6
```

The environmental variable `MYSQL_SUBNET` is optional but can be used to generate users with access to databases outside the `localhost`, (the default for the root user). In the example, the subnet definition `0.0.0.0/0.0.0.0` allows connections from any network which is equivalent to the wildcard symbol, `%`, in MySQL GRANT definitions.

Now you can verify it is initialised and running successfully by inspecting the container's logs:

```
$ docker logs mysql.pool-1.1.1
```

#### Environment Variables

There are several environmental variables defined at runtime these allow the operator to customise the running container.

*Note:* Most of these settings are only evaluated during the first run of a named container; if the data volume already exists and contains database table data then changing these values will have no effect.

##### MYSQL_ROOT_PASSWORD

On first run the root user is created with an auto-generated password. If you require a specific password,  `MYSQL_ROOT_PASSWORD` can be used when running the container.

```
...
  --env "MYSQL_ROOT_PASSWORD=Passw0rd!" \
...
```

##### MYSQL_ROOT_PASSWORD_HASHED

To indicate `MYSQL_ROOT_PASSWORD` is a pre-hashed value instead of the default plain-text type set `MYSQL_ROOT_PASSWORD_HASHED` to `true`.

```
...
  --env "MYSQL_ROOT_PASSWORD=*03F7361A0E18DA99361B7A82EA575944F53E206B" \
  --env "MYSQL_ROOT_PASSWORD_HASHED=true" \
...
```

*Note:* To generate a pre-hashed password you could use the following MySQL command.

```
$ mysql -u root -p{mysql_root_password} \
  -e "SELECT PASSWORD('{mysql_user_password}');"
```

##### MYSQL_USER

On first run, a database user and database can be created. Set `MYSQL_USER` to a non-empty string. A corresponding `MYSQL_USER_DATABASE` value must also be set for the user to be given access too.

```
...
  --env "MYSQL_USER=app-user" \
...
```

##### MYSQL_USER_PASSWORD

On first run, if the database user `MYSQL_USER` is specified then it is created with an auto-generated password. If you require a specific password,  `MYSQL_USER_PASSWORD` can be used when running the container.

```
...
  --env "MYSQL_USER_PASSWORD=appPassw0rd!" \
...
```

##### MYSQL_USER_PASSWORD_HASHED

To indicate `MYSQL_USER_PASSWORD` is a pre-hashed value instead of the default plain-text type set `MYSQL_USER_PASSWORD_HASHED` to `true`.

```
...
  --env "MYSQL_USER_PASSWORD=*4215553ECE7A18BC09C16DB9EBF03FACFF49166B" \
  --env "MYSQL_USER_PASSWORD_HASHED=true" \
...
```

##### MYSQL_USER_DATABASE

On first run, if the database user `MYSQL_USER` is specified then you must also define a corresponding database name.  `MYSQL_USER_DATABASE` can be used when running the container.

```
...
  --env "MYSQL_USER_DATABASE=app-db" \
...
```
