# Change Log

## centos-7-mysql57-community

Summary of release changes for Version 2.

CentOS-7 7.5.1804 x86_64 - MySQL 5.7 Community Server.

### 2.2.0 - Unreleased

- Updates source image to [2.5.0](https://github.com/jdeathe/centos-ssh/releases/tag/2.5.0).
- Updates and restructures Dockerfile.
- Updates container naming conventions and readability of `Makefile`.
- Updates `mysql-community-server` package to 5.7.25-1.
- Fixes issue with unexpected published port in run templates when `DOCKER_PORT_MAP_TCP_3306` is set to an empty string or 0.
- Adds placeholder replacement of `RELEASE_VERSION` docker argument to systemd service unit template.
- Adds consideration for event lag into test cases for unhealthy health_status events.
- Adds port incrementation to Makefile's run template for container names with an instance suffix.
- Adds supervisord check to healthcheck script and removes unnecessary source script.
- Adds images directory `.dockerignore` to reduce size of build context.
- Removes use of `/etc/services-config` paths.
- Removes code from configuration file `/etc/mysqld-bootstrap.conf`.
- Removes X-Fleet section from etcd register template unit-file.
- Removes the unused group element from the default container name.
- Removes the node element from the default container name.
- Removes unused environment variables from Makefile and scmi configuration.

### 2.1.1 - 2018-11-18

- Updates source image to [2.4.1](https://github.com/jdeathe/centos-ssh/releases/tag/2.4.1).
- Adds missing error messages to internal healthcheck.

### 2.1.0 - 2018-08-23

- Updates source image to [2.4.0](https://github.com/jdeathe/centos-ssh/releases/tag/2.4.0).

### 2.0.0 - 2018-08-07

- Initial release.