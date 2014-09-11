centos-ssh-mysql
================

Docker Image including CentOS-6, MySQL 5.1.

The Dockerfile can be used to build a base image that can be run as-is or used as the bases for other more specific builds.

Included in the build is the EPEL repository and SSH, vi and MySQL are installed along with python-pip, supervisor and supervisor-stdout.

[Supervisor](http://supervisord.org/) is used to start mysqld (and optionally the sshd) daemon when a docker container based on this image is run. To enable simple viewing of stdout for the sshd subprocess, supervisor-stdout is included. This allows you to see output from the supervisord controlled subprocesses with `docker logs <docker-container-name>`.

SSH is not required in order to access a terminal for the running container the prefered method is to use Command Keys and the nsenter command. See [command-keys.md](https://github.com/jdeathe/centos-ssh-mysql/blob/master/command-keys.md) for details on how to set this up.

If enabling and configuring SSH access, it is by public key authentication and, by default, the [Vagrant](http://www.vagrantup.com/) [insecure private key](https://github.com/mitchellh/vagrant/blob/master/keys/vagrant) is required.

## Quick Example

Run up a container named ```mysql.pool-1.1.1``` from the docker image ```jdeathe/centos-ssh-mysql``` on port 3306 of your docker host.

```
$ docker run -d \
  --name mysql.pool-1.1.1 \
  -p 3306:3306 \
  -v /var/services-data/mysql/pool-1:/var/lib/mysql \
  jdeathe/centos-ssh-mysql:latest
```

Now you can verify it is initialised and running successfully by inspecting the container's logs.

```
$ docker logs mysql.pool-1.1.1
```

If it is the first run there should be additional output showing the initialisation SQL that was run and the root user's password. The mysql table data is persistent accross container restarts by mapping the MySQL data directory ```/var/lib/mysql``` to the Docker host's mysql services-data directory ```/var/services-data/mysql/pool-1```. For this service, "pool-1" indicates that this data directory can be shared among several containers of the same pool ID.

![Docker Logs MySQL Bootstrap](https://raw.github.com/jdeathe/centos-ssh-mysql/master/images/docker-logs-mysql-bootstrap.png)

*Note:* If you need a clean installation, (and wish to destroy all existing MySQL databases for the shared pool), simply remove the contents of ```/var/services-data/mysql/pool-1``` and restart the container using: ```docker restart mysql.pool-1.1.1```.

## Instructions

### (Optional) Configuration Data Volume

Create a "data volume" for configuration, this allows you to share the same configuration between multiple docker containers and, by mounting a host directory into the data volume you can override the default configuration files provided. The Configuration Volume is then used to provide access to the common configuration directories and files required by the service by way of the "```--volumes-from``` Docker run command.

Each service that requires a common set of configuration files should use a single Configuration Volume as illustrated in the following diagram:

```
+---------------------------------------------------+
|                (Docker Host system)               |
|                                                   |
| /etc/service-config/<service-name>                |
|                         +                         |
|                         |                         |
|            +============*===========+             |
|            |  Configuration Volume  |             |
|            |    Service Container   |             |
|            +============*===========+             |
|                         |                         |
|         +---------------*---------------+         |
|         |               |               |         |
|   +=====*=====+   +=====*=====+   +=====*=====+   |
|   |  Service  |   |  Service  |   |  Service  |   |
|   | Container |   | Container |   | Container |   |
|   |    (1)    |   |    (2)    |   |    (n)    |   |
|   +===========+   +===========+   +===========+   |
+---------------------------------------------------+

```

Make a directory on the docker host for storing container configuration files. This directory needs to contain everything from the directory [etc/services-config](https://github.com/jdeathe/centos-ssh-mysql/blob/master/etc/services-config)

```
$ mkdir -p /etc/services-config/mysql.pool-1.1.1
```

Create the data volume, mounting the applicable docker host's configuration directories to the associated  */etc/services-config/* sub-directories in the docker container. Docker will pull the busybox:latest image if you don't already have it available locally.

```
$ docker run \
  --name volume-config.mysql.pool-1.1.1 \
  -v /etc/services-config/mysql.pool-1.1.1/supervisor:/etc/services-config/supervisor \
  -v /etc/services-config/mysql.pool-1.1.1/mysql:/etc/services-config/mysql \
  busybox:latest \
  /bin/true
```

If enabling the SSH service in the supervisor configuration you can define a persistent authorized key for SSH access by mounting the ssh.pool-1 directory and adding the key there.

```
$ docker run \
  --name volume-config.mysql.pool-1.1.1 \
  -v /etc/services-config/ssh.pool-1:/etc/services-config/ssh \
  -v /etc/services-config/mysql.pool-1.1.1/supervisor:/etc/services-config/supervisor \
  -v /etc/services-config/mysql.pool-1.1.1/mysql:/etc/services-config/mysql \
  busybox:latest \
  /bin/true
```

### Running

To run the a docker container from this image you can use the included [run.sh](https://github.com/jdeathe/centos-ssh-mysql/blob/master/run.sh) and [run.conf](https://github.com/jdeathe/centos-ssh-mysql/blob/master/run.conf) scripts. The helper script will stop any running container of the same name, remove it and run a new daemonised container on an unspecified host port. Alternatively you can use the following to make the service available on port 3306 of the docker host.

```
$ docker stop mysql.pool-1.1.1 && \
  docker rm mysql.pool-1.1.1
$ docker run -d \
  --name mysql.pool-1.1.1 \
  -p 3306:3306 \
  --env MYSQL_SUBNET=% \
  --volumes-from volume-config.mysql.pool-1.1.1 \
  -v /var/services-data/mysql/pool-1:/var/lib/mysql \
  jdeathe/centos-ssh-mysql:latest
```

The environmental variable ```MYSQL_SUBNET``` is optional but can be used\* with the [MySQL bootstrap configuration file](https://github.com/jdeathe/centos-ssh-mysql/blob/master/etc/services-config/mysql/mysql-bootstrap.conf) to generate users with access to databases outside the localhost, (which is the default for the root user); in the example, the wildcard symbol, (%), is used to allow access from any host given the correct user and password.

\**There is an example use case in the bootstrap configuration file.*

Now you can verify it is initialised and running successfully by inspecting the container's logs:

```
$ docker logs mysql.pool-1.1.1
```
