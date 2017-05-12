# Change Log

## centos-6

Summary of release changes for Version 1.

CentOS-6 6.8 x86_64 - MySQL 5.1.

### 1.7.3 - Unreleased

- Updates upstream source to [1.7.6 tag](https://github.com/jdeathe/centos-ssh/releases/tag/1.7.6).
- Updates MySQL package to `mysql-server-5.1.73-8.el6_8`.
- Adds a change log (`CHANGELOG.md`).
- Adds support for semantic version numbered tags.
- Adds minor code style changes to the Makefile for readability.
- Adds support for running `shpec` functional tests with `make test`.

### 1.7.2 - 2016-10-02

- Adds Makefile help target with usage instructions.
- Splits up the Makefile targets into internal and public types.
- Adds correct `scmi` path in usage instructions.
- Changes `PACKAGE_PATH` to `DIST_PATH` in line with the Makefile environment include. Not currently used by `scmi` but changing for consistency.
- Changes `DOCKER_CONTAINER_PARAMETERS_APPEND` to `DOCKER_CONTAINER_OPTS` for usability. This is a potentially breaking change that could affect systemd service configurations if using the Environment variable in a drop-in customisation. However, if using the systemd template unit-files it should be pinned to a specific version tag. The Makefile should only be used for development/testing and usage in `scmi` is internal only as the `--setopt` parameter is used to build up the optional container parameters. 
- Removes X-Fleet section from template unit-file.

### 1.7.1 - 2016-09-15

- Adds scmi and systemd configuration files to image.
- Adds option to disable publishing of 3306 in make/scmi and systemd templates.
- Updated README with some minor corrections and changes for consistency.
- Updates the install/uninstall metadata labels to use the correct path to the scmi script on the image to allow the atomic install/uninstall feature to work as expected.
- Updates README examples to use the 1.7.1 release version.
- Adds new `mysqld-wrapper` script which is more easily maintained than using inline code in the supervisord configuration.
- Adds general consistency improvements to the `mysqld-bootstrap` script.

### 1.7.0 - 2016-09-06

- Updates upstream source to [1.7.0 tag](https://github.com/jdeathe/centos-ssh/releases/tag/1.7.0).
- Adds `scmi` and metadata for atomic install/uninstall usage.
- Removes deprecated run.sh and build.sh helper scripts. These have been replaced with the make targets `make` (or `make build`) and `make install start`.
- Removes support for and documentation on configuration volumes. These can still be implemented by making use of the `DOCKER_CONTAINER_PARAMETERS_APPEND` environment variable or using the `scmi` option `--setopt` to append additional docker parameters to the default docker create template.
- Changes systemd template unit-file environment variable for `DOCKER_IMAGE_PACKAGE_PATH` now defaults to the path `/var/opt/scmi/packages` instead of `/var/services-packages` however this can be reverted back using the `scmi` option `--env='DOCKER_IMAGE_PACKAGE_PATH="/var/services-packages"'` if necessary.
- Changes the recommended data volume name for mapping to the container path: `/var/lib/mysql` from `volume-data.mysql.pool-1.1.1` to `mysql.pool-1.1.1.data-mysql`. This makes it easier to sort output of `docker volume ls`.

### 1.6.0 - 2016-09-05

- Updates upstream source image to [1.6.0 tag](https://github.com/jdeathe/centos-ssh/releases/tag/1.6.0) (i.e. CentOS-6.8).
- Improves readability of Dockerfile.
- Updates Makefile to fix issue running `make dist` without first creating the `PACKAGE_PATH`, (./packages/jdeathe), directory.
- Adds `DOCKER_CONTAINER_PARAMETERS_APPEND` to the Makefile create template.
- Adds an improvements to the optional etcd register template unit-file used in systemd installations.
- Adds `DOCKER_USER` to the systemd template unit-file environment variables and removes the docker username from the `DOCKER_IMAGE_NAME` for consistency.

### 1.5.0 - 2016-07-09

- Updates upstream source image to [1.5.3 tag](https://github.com/jdeathe/centos-ssh/releases/tag/1.5.3).
- Updates mysql-server package to version 5.1.73-7.el6.
- Changes supervisord configuration and `mysqld-bootstrap` script.
- Splits out the docker helper functions used by the `build.sh` and `run.sh` scripts.
- Changes to start mysqld process after `mysqld-boostrap` completes successfully.
- Adds make files for docker build/run jobs.
- Adds updated systemd unit file template with optional etcd register companion service.
- Adds change to skip networking during `mysql-boostrap` initialisation.
- Adds `skip-name-resolve` to the default MySQL configuration to mitigate resolver issues causing database authentication failures.
- Adds support for multiline initialisation SQL.
- Adds more informative output to logs from `mysql-bootstrap`.
- Changes the SQL used to generate database,user,grants to be outside of the configuration file.
- Adds `MYSQL_ROOT_PASSWORD_HASHED` to allow for the use of a hashed root password.
- Adds `MYSQL_USER_PASSWORD_HASHED` to allow for the use of a hashed user password.
- Adds feature to redact password values from log output if operator supplied.

### 1.4.2 - 2016-01-17

- Updates documentation with revised steps on how to implement the optional configuration "data" volume. Also revised for the application data volume.
- Updates the Systemd installation and definition scripts - no longer require the busybox image and made the installation easier to visualise by tailing the unit logs. Removes the necessity to create and populate the configuration data volume directory mount points.
- Removes the `run.sh` feature to automatically mount the configuration volume on the docker host using a full path and attempt to populate the directory locally. This was problematic since the path on the Docker host might not exist and the feature to automatically create paths when adding a volume mount is deprecated. Using `docker cp` to upload a directory to the configuration volume is the preferred approach.
- Updates `run.conf` such that only values are in the configuration file and added `VOLUME_CONFIG_ENABLED` to allow the "optional" configuration volume to be enabled if required instead of using it by default. Most essential settings can be implemented via the use of environment variables now. Also addes the variable `VOLUME_DATA_ENABLED` to allow the optional use of a named data container instead of defining the volume within the running application container.
- Addes `VOLUME_CONFIG_NAMED` and `VOLUME_DATA_NAMED` to `run.conf` to allow the operator to use named volumes and, if set to `true` the values are is used for the `docker_host_path` such that the volume is defined as: `-v volume_name:/container_path`. The recommended approach is to not define a host path or named volume if using a separate configuration/data container so that Docker manages the naming by only setting the container path: `-v /container_path`.
- Addes new `run.conf` variables `DOCKER_HOST_PORT_SSH` and `DOCKER_HOST_PORT_MYSQL` to allow the operator to easily change the values from those set in the `run.sh` helper script.

### 1.4.1 - 2016-01-10

- Updates upstream source image to [1.4.1 tag](https://github.com/jdeathe/centos-ssh/releases/tag/1.4.1).
- Adds more consistent syntax across BASH scripts.
- Fixes an issue that prevented the `run.sh` from running correctly.
- Addes code comment example for how to use the `run.sh` script to run a command in a container at docker run time; This is helpful for debugging containers that don't stay running.
- Addes initialisation testing of database access for the `MYSQL_USER` user against the `MYSQL_USER_DATABASE` database if values are set.
- Updates README file with more recent image of the docker logs output.
- Adds examples of how to run the mysql shell and how to import data.

### 1.4.0 - 2015-12-09

- Updates to CentOS 6.7.

### 1.3.1 - 2015-12-09

- Updates upstream source image to [1.3.1 tag](https://github.com/jdeathe/centos-ssh/releases/tag/1.3.1).
- Adds delay to allow the custom initialisation SQL to run at startup.
- Adds better verification of completion of the initialisation process in the mysql-bootstrap script.
- Adds feature to allow first-load configuration with environment variables. Now the database name, user and password can be set on first run.
- Updates the docker network helper functions and moves them out of the configuration file.
- Updates the systemd install script to use helper functions + updates the service definition file to use etcd2.

### 1.3.0 - 2015-08-03

- Change to build from a specified tag instead of branch.
- Change build to use specific package versions, add versionlock package and lock packages.
- Change location of the SSH configuration file to a subdirectory.
- Adds support for running and building on Mac Docker hosts (when using boot2docker).
- Adds a 2 second delay to supervisor's MySQL startup script to allow mysql-bootstrap to run first.
- Adds some improvements to the mysql-bootstrap script.
  - Run the initial table installation in the background so the the initialisation SQL can be generated in the foreground.
  - Removes the MySQL shutdown since this should not longer be necessary.
  - Improves the readability by using heredoc syntax for the multiline text instead of lots of echo calls.
  - The permissions on the MySQL data directory are used determine the service users UID/GID this was added for support on Mac hosts with either boot2docker or Kitematic.
  - Moves the socket file out of the MySQL data directory. 
- Adds some improvements to the run.sh helper script.
  - Makes the configuration volume the same for both SSH and non-SSH containers.
  - Defines the docker run command once and set up the port requirements for SSH if necessary.
- Fixes an issue with deprecated option warnings in the MySQL configuration.

### 1.2.2 - 2015-07-27

- Fixes an issue with the init scripts/SQL not running due to Supervisord starting the mysqld process between database creation and running the init scripts.
- Adds configuration change to force a default UTF8 character set for the connection and results.

### 1.2.1 - 2015-05-25

- Updates the systemd service file to reference the correct tag version.
- Fixes a few spelling errors in the README file.

### 1.2.0 - 2015-05-03

*Note:* This should have been tagged as 1.1.0.

- Updates CentOS to 6.6.
- Adds MIT License.

### 1.0.1 - 2014-09-15

- Removes the SSH port mapping from the systemd unit file since SSH is not enabled by default.

### 1.0.0 - 2014-09-14

- Initial release.