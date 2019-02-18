# Change Log

## centos-7-mysql57-community

Summary of release changes for Version 2.

CentOS-7 7.5.1804 x86_64 - MySQL 5.7 Community Server.

### 2.2.0 - Unreleased

- Updates source image to [2.5.0](https://github.com/jdeathe/centos-ssh/releases/tag/2.5.0).
- Updates and restructures Dockerfile.
- Adds placeholder replacement of `RELEASE_VERSION` docker argument to systemd service unit template.
- Adds consideration for event lag into test cases for unhealthy health_status events.
- Removes use of `/etc/services-config` paths.
- Removes code from configuration file `/etc/mysqld-bootstrap.conf`.
- Removes X-Fleet section from etcd register template unit-file.

### 2.1.1 - 2018-11-18

- Updates source image to [2.4.1](https://github.com/jdeathe/centos-ssh/releases/tag/2.4.1).
- Adds missing error messages to internal healthcheck.

### 2.1.0 - 2018-08-23

- Updates source image to [2.4.0](https://github.com/jdeathe/centos-ssh/releases/tag/2.4.0).

### 2.0.0 - 2018-08-07

- Initial release.