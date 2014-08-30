centos-ssh-mysql
================

Docker Image including CentOS-6, MySQL 5.1.

The Dockerfile can be used to build a base image that can be run as-is or used as the bases for other more specific builds.

Included in the build is the EPEL repository and SSH, vi and MySQL are installed along with python-pip, supervisor and supervisor-stdout.

[Supervisor](http://supervisord.org/) is used to start mysqld (and optionally the sshd) daemon when a docker container based on this image is run. To enable simple viewing of stdout for the sshd subprocess, supervisor-stdout is included. This allows you to see output from the supervisord controlled subprocesses with `docker logs <docker-container-name>`.

SSH is not required in order to access a terminal for the running container the prefered method is to use Command Keys and the nsenter command. See [command-keys.md](command-keys.md) for details on how to set this up.

If enabling and configuring SSH access, it is by public key authentication and, by default, the [Vagrant](http://www.vagrantup.com/) [insecure private key](https://github.com/mitchellh/vagrant/blob/master/keys/vagrant) is required.

## Quick Example

Run up a container named ```mysql.pool-1.1.1``` from the docker image ```jdeathe/centos-ssh-mysql``` on port 3306 of your docker host.

```
$ docker run -d \
  mysql.pool-1.1.1 \
  -p 3306:3306 \
  -v /etc/services-config/mysql.pool-1.1.1/mysql:/etc/services-config/mysql \
  jdeathe/centos-ssh-mysql:latest
```