# Change Log

## 2 - centos-7-mysql57-community

Summary of release changes.

### 2.3.0 - Unreleased

- Updates source image to [2.6.0](https://github.com/jdeathe/centos-ssh/releases/tag/2.6.0).
- Updates `mysql-community-server` package to 5.7.26-1.
- Updates CHANGELOG.md to simplify maintenance.
- Updates README.md to simplify contents and improve readability.
- Updates README-short.txt to apply to all image variants.
- Updates Dockerfile `org.deathe.description` metadata LABEL for consistency.
- Updates order of supervisord configuration directives for consistency.
- Updates supervisord configuration to send error log output to stderr.
- Updates bootstrap supervisord configuration file/priority to `20-mysqld-bootstrap.conf`/`20`.
- Updates wrapper supervisord configuration file/priority to `50-mysqld-wrapper.conf`/`50`.
- Updates default value of `MYSQL_INIT_LIMIT` to 10 from 60 seconds.
- Fixes docker host connection status check in Makefile.
- Fixes default `MYSQL_INIT_LIMIT` value in systemd unit file template.
- Adds `inspect`, `reload` and `top` Makefile targets.
- Adds improved `clean` Makefile target; includes exited containers and dangling images.
- Adds `SYSTEM_TIMEZONE` handling to Makefile, scmi, systemd unit and docker-compose templates.
- Adds system time zone validation to healthcheck.
- Adds lock/state file to bootstrap/wrapper scripts.
- Adds all necessary auto-generated TLS/SSL pem files to data directory during bootstrap.
- Adds improved bootstrap handling of previously initialised datadir.
- Adds a note in example docker-compose.yml that `MYSQL_ROOT_PASSWORD` is required when using a data volume.
- Adds `MYSQL_INIT_LIMIT` and `MYSQL_INIT_SQL` to docker-compose example.
- Removes `MYSQL_AUTOSTART_MYSQL_BOOTSTRAP`, replaced with `ENABLE_MYSQL_BOOTSTRAP`.
- Removes `MYSQL_AUTOSTART_MYSQL_WRAPPER`, replaced with `ENABLE_MYSQL_WRAPPER`.
- Removes support for long image tags (i.e. centos-7-mysql57-community-2.x.x).
- Removes unnecessary use of `FLUSH PRIVILEGES` in intitialisation SQL.
- Removes `log-error=/var/log/mysqld.log` from default configuration; log to stderr.

### 2.2.0 - 2019-03-18

- Updates source image to [2.5.1](https://github.com/jdeathe/centos-ssh/releases/tag/2.5.1).
- Updates and restructures Dockerfile.
- Updates container naming conventions and readability of `Makefile`.
- Updates `mysql-community-server` package to 5.7.25-1.
- Updates Dockerfile with combined ADD to reduce layer count in final image.
- Fixes issue with unexpected published port in run templates when `DOCKER_PORT_MAP_TCP_3306` is set to an empty string or 0.
- Fixes binary paths in systemd unit files for compatibility with both EL and Ubuntu hosts.
- Adds placeholder replacement of `RELEASE_VERSION` docker argument to systemd service unit template.
- Adds consideration for event lag into test cases for unhealthy health_status events.
- Adds port incrementation to Makefile's run template for container names with an instance suffix.
- Adds supervisord check to healthcheck script and removes unnecessary source script.
- Adds images directory `.dockerignore` to reduce size of build context.
- Adds docker-compose configuration example.
- Adds improved logging output.
- Adds improved root password configuration.
- Adds improvement to pull logic in systemd unit install template.
- Adds `SSH_AUTOSTART_SUPERVISOR_STDOUT` with a value "false", disabling startup of `supervisor_stdout`.
- Adds improved `healtchcheck`, `sshd-bootstrap` and `sshd-wrapper` scripts.
- Adds `MYSQL_INIT_LIMIT` with a default value of "60" seconds.
- Adds `MYSQL_INIT_SQL` with a default empty value "".
- Deprecates `CUSTOM_MYSQL_INIT_SQL`, use `MYSQL_INIT_SQL` instead.
- Removes use of `/etc/services-config` paths.
- Removes use of `/etc/mysqld-bootstrap.conf`.
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