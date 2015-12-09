centos-ssh-mysql
================

Docker Image of CentOS-6 6.7 x86_64, MySQL 5.1.

Includes Automated password generation and an option for custom initialisation SQL. Supports custom configuration via a configuration data volume.

## Overview & links

The [Dockerfile](https://github.com/jdeathe/centos-ssh-mysql/blob/centos-6/Dockerfile) can be used to build a base image that can be run as-is or used as the bases for other more specific builds.

Included in the build is the EPEL repository and SSH, vi and MySQL are installed along with python-pip, supervisor and supervisor-stdout.

[Supervisor](http://supervisord.org/) is used to start mysqld (and optionally the sshd) daemon when a docker container based on this image is run. To enable simple viewing of stdout for the sshd subprocess, supervisor-stdout is included. This allows you to see output from the supervisord controlled subprocesses with `docker logs <docker-container-name>`.

If enabling and configuring SSH access, it is by public key authentication and, by default, the [Vagrant](http://www.vagrantup.com/) [insecure private key](https://github.com/mitchellh/vagrant/blob/master/keys/vagrant) is required.

### SSH Alternatives

SSH is not required in order to access a terminal for the running container. The simplest method is to use the docker exec command to run bash (or sh) as follows: 

```
$ docker exec -it <docker-name-or-id> bash
```

For cases where access to docker exec is not possible the preferred method is to use Command Keys and the nsenter command. See [command-keys.md](https://github.com/jdeathe/centos-ssh-mysql/blob/centos-6/command-keys.md) for details on how to set this up.

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

If it is the first run there should be additional output showing the initialisation SQL that was run and the root user's password. The mysql table data is persistent across container restarts by mapping the MySQL data directory ```/var/lib/mysql``` to the Docker host's mysql services-data directory ```/var/services-data/mysql/pool-1```. For this service, "pool-1" indicates that this data directory can be shared among several containers of the same pool ID.

![Docker Logs MySQL Bootstrap](https://raw.github.com/jdeathe/centos-ssh-mysql/centos-6/images/docker-logs-mysql-bootstrap.png)

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

Make a directory on the docker host for storing container configuration files. This directory needs to contain everything from the directory [etc/services-config](https://github.com/jdeathe/centos-ssh-mysql/blob/centos-6/etc/services-config)

```
$ mkdir -p /etc/services-config/mysql.pool-1.1.1
```

Create the data volume, mounting the applicable docker host's configuration directories to the associated  */etc/services-config/* sub-directories in the docker container. Docker will pull the busybox:latest image if you don't already have it available locally.

If enabling the SSH service in the supervisor configuration you can define a persistent authorised key for SSH access by mounting the ssh.pool-1 directory and adding the key there.

```
$ docker run \
  --name volume-config.mysql.pool-1.1.1 \
  -v /etc/services-config/ssh.pool-1/ssh:/etc/services-config/ssh \
  -v /etc/services-config/mysql.pool-1.1.1/supervisor:/etc/services-config/supervisor \
  -v /etc/services-config/mysql.pool-1.1.1/mysql:/etc/services-config/mysql \
  busybox:latest \
  /bin/true
```

### Running

To run the a docker container from this image you can use the included [run.sh](https://github.com/jdeathe/centos-ssh-mysql/blob/centos-6/run.sh) and [run.conf](https://github.com/jdeathe/centos-ssh-mysql/blob/centos-6/run.conf) scripts. The helper script will stop any running container of the same name, remove it and run a new daemonised container on an unspecified host port. Alternatively you can use the following methods to make the service available on port 3306 of the docker host. 

#### Using environment variables

The following example sets up a custom MySQL database, user and user password on first run. This will only work when MySQL runs the initialisation process and values must be specified for MYSQL_USER and MYSQL_USER_DATABASE. If MYSQL_USER_PASSWORD is not specified or left empty a random password will be generated.

*Note:* Settings applied by environment variables will override those set within configuration volumes from release 1.3.1. Existing installations that use the mysql-bootstrap.conf saved on a configuration "data" volume will not allow override by the environment variables. Also users can update mysql-bootstrap.conf to prevent the value being replaced by that set using the environment variable.

```
$ docker stop mysql.pool-1.1.1 && \
  docker rm mysql.pool-1.1.1
$ docker run -d \
  --name mysql.pool-1.1.1 \
  -p 3306:3306 \
  --env "MYSQL_SUBNET=localhost" \
  --env "MYSQL_USER=user" \
  --env "MYSQL_USER_PASSWORD=" \
  --env "MYSQL_USER_DATABASE=userdb" \
  -v /var/services-data/mysql/pool-1:/var/lib/mysql \
  jdeathe/centos-ssh-mysql:latest
```

#### Using configuration volume

The following example uses the settings from the optonal configuration volume volume-config.mysql.pool-1.1.1 and maps a data volume for persistent storage of the MySQL data on the docker host.

*Note:* If you are following on from the previous example you will need to delete or rename the data directory on the docker host if you want the database initialisation process to be carried out again.

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

The environmental variable ```MYSQL_SUBNET``` is optional but can be used\* with the [MySQL bootstrap configuration file](https://github.com/jdeathe/centos-ssh-mysql/blob/centos-6/etc/services-config/mysql/mysql-bootstrap.conf) to generate users with access to databases outside the localhost, (which is the default for the root user); in the example, the wildcard symbol, (%), is used to allow access from any host given the correct user and password.

\**There is an example use case in the bootstrap configuration file.*

Now you can verify it is initialised and running successfully by inspecting the container's logs:

```
$ docker logs mysql.pool-1.1.1
```

### Custom Configuration

If using the optional data volume for container configuration you are able to customise the configuration. In the following examples your custom docker configuration files should be located on the Docker host under the directory ```/etc/service-config/<container-name>/``` where ```<container-name>``` should match the applicable container name such as "mysql.pool-1.1.1" in the examples.

#### [mysql/mysql-bootstrap.conf](https://github.com/jdeathe/centos-ssh-mysql/blob/centos-6/etc/services-config/mysql/mysql-bootstrap.conf)

The bootstrap script initialises the app. It initialises the MySQL install with ```/usr/bin/mysql_install_db``` then secures the install and applies any custom SQL with ```/usr/bin/mysqld_safe``` - any test or root users and test databases are dropped, then a password for the localhost only MySQL root user is generated.

#### [mysql/my.cnf](https://github.com/jdeathe/centos-ssh-mysql/blob/centos-6/etc/services-config/mysql/my.cnf)

MySQL can be configured via the my.cnf - refer to the MySQL documentation with respect to what settings are available.

#### [supervisor/supervisord.conf](https://github.com/jdeathe/centos-ssh-mysql/blob/centos-6/etc/services-config/supervisor/supervisord.conf)

The supervisor service's configuration can also be overridden by editing the custom supervisord.conf file. It shouldn't be necessary to change the existing configuration here but you could include more [program:x] sections to run additional commands at startup.