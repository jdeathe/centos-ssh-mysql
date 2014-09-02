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