## Tags and respective `Dockerfile` links

- `centos-7-mysql57-community`, [`2.3.0`](https://github.com/jdeathe/centos-ssh-mysql/tree/2.3.0)  [(centos-7-mysql57-community/Dockerfile)](https://github.com/jdeathe/centos-ssh-mysql/blob/centos-7-mysql57-community/Dockerfile)
- `centos-6`, [`1.11.0`](https://github.com/jdeathe/centos-ssh-mysql/tree/1.11.0) [(centos-6/Dockerfile)](https://github.com/jdeathe/centos-ssh-mysql/blob/centos-6/Dockerfile)

## Overview

This build uses the base image [jdeathe/centos-ssh](https://github.com/jdeathe/centos-ssh) so inherits it's features but with `sshd` disabled by default. [Supervisor](http://supervisord.org/) is used to start the [`mysqld`](https://www.mysql.com/products/community/) daemon when a docker container based on this image is run.

Includes automated password generation and an option for custom initialisation SQL.

### Image variants

- [MySQL 5.7 Community Server - CentOS-7](https://github.com/jdeathe/centos-ssh-mysql/blob/centos-7-mysql57-community)
- [MySQL 5.1 - CentOS-6](https://github.com/jdeathe/centos-ssh-mysql/blob/centos-6)

## Quick start

> For production use, it is recommended to select a specific release tag as shown in the examples.

Run up a container named `mysql.1` from the docker image `jdeathe/centos-ssh-mysql` on port 3306 of your docker host.

```
$ docker run -d \
  --name mysql.1 \
  -p 3306:3306 \
  -v /var/lib/mysql \
  jdeathe/centos-ssh-mysql:2.3.0
```

Verify the named container's process status and health.

```
$ docker ps -a \
  -f "name=mysql.1"
```

Verify successful initialisation of the named container.

```
$ docker logs mysql.1
```

On first run, MySQL Details are returned. This includes the configured database, if applicable, and any associated user credentials.

![Docker Logs - MySQL Bootstrap](https://raw.github.com/jdeathe/centos-ssh-mysql/centos-7-mysql57-community/images/docker-logs-mysqld-bootstrap-v2.3.0.png)

The MySQL table data is persistent across container restarts by setting the MySQL data directory `/var/lib/mysql` as a data volume. To locate the path where data is stored on the Docker host use `docker inspect`.

```
$ docker inspect \
  --format '{{ json (index .Mounts 0).Source }}' \
  mysql.1
```

To access the interactive MySQL SQL shell.

```
$ docker exec -it \
  mysql.1 \
  mysql
```
### Sakila example

Import the Sakila example database from the [MySQL Documentation](https://dev.mysql.com/doc/index-other.html) and view the first 2 records from the film table.

#### Import schema

```
$ docker exec -i mysql.1 mysql \
  <<< $(curl -sSL http://downloads.mysql.com/docs/sakila-db.tar.gz \
    | tar -xzO - "sakila-db/sakila-schema.sql" \
    | sed -e '/^CREATE TABLE film_text/,/ENGINE=InnoDB / s/InnoDB/MyISAM/'
  )
```

#### Import data

```
$ docker exec -i mysql.1 mysql \
  <<< $(curl -sSL http://downloads.mysql.com/docs/sakila-db.tar.gz \
    | tar -xzO - "sakila-db/sakila-data.sql"
  )
```

#### Select records

```
$ docker exec mysql.1 mysql \
  -e "SELECT * FROM sakila.film LIMIT 2 \G"
```

## Instructions

### Running

To run the a docker container from this image you can use the standard docker commands as shown in the example below. Alternatively, there's a [docker-compose](https://github.com/jdeathe/centos-ssh-mysql/blob/centos-7-mysql57-community/docker-compose.yml) example.

For production use, it is recommended to select a specific release tag as shown in the examples.

#### Using environment variables

The following example sets up a custom MySQL database, user and user password on first run. This will only work when MySQL runs the initialisation process and values must be specified for `MYSQL_USER` and `MYSQL_USER_DATABASE`. If `MYSQL_USER_PASSWORD` is not specified or left empty a random password will be generated.

```
$ docker stop mysql.1 && \
  docker rm mysql.1; \
  docker run \
  --detach \
  --name mysql.1 \
  --publish 3306:3306 \
  --env "MYSQL_SUBNET=0.0.0.0/0.0.0.0" \
  --env "MYSQL_USER=app-user" \
  --env "MYSQL_USER_PASSWORD=" \
  --env "MYSQL_USER_DATABASE=app-db" \
  --volume mysql.1.data-mysql:/var/lib/mysql \
  jdeathe/centos-ssh-mysql:2.3.0
```

The environmental variable `MYSQL_SUBNET` is optional but can be used to generate users with access to databases outside the `localhost`, (the default for the root user). In the example, the subnet definition `0.0.0.0/0.0.0.0` allows connections from any network which is equivalent to the wildcard symbol, `%`, in MySQL GRANT definitions.

Verify it's initialised and running successfully by inspecting the container's logs:

```
$ docker logs mysql.1
```

#### Environment variables

There are several environmental variables defined at runtime these allow the operator to customise the running container.

> *Note:* Most of these settings are only evaluated during the first run of a named container; if the data volume already exists and contains database table data then changing these values will have no effect.

##### ENABLE_MYSQLD_BOOTSTRAP & ENABLE_MYSQLD_WRAPPER

It may be desirable to prevent the startup of the mysqld-bootstrap and/or mysqld-wrapper scripts. For example, when using an image built from this Dockerfile as the source for another Dockerfile you could disable both mysqld-wrapper and mysqld from startup by setting `ENABLE_MYSQLD_BOOTSTRAP` and `ENABLE_MYSQLD_WRAPPER` to `false`. The benefit of this is to reduce the number of running processes in the final container. Another use for this would be to make use of the packages installed in the image such as `mysql` and `mysqladmin`; effectively making the container a MySQL client.

```
...
  --env "ENABLE_MYSQLD_BOOTSTRAP=false" \
  --env "ENABLE_MYSQLD_WRAPPER=false" \
...
```

##### MYSQL_INIT_LIMIT

The default timeout for MySQL initialisation is 10 seconds. Use `MYSQL_INIT_LIMIT` to change this value when necessary.

```
...
  --env "MYSQL_INIT_LIMIT=30" \
...
```

##### MYSQL_INIT_SQL

To add custom SQL to the MySQL intitialisation use `MYSQL_INIT_SQL` where the following placeholders are will get replaced with the appropriate values:

- `{{MYSQL_ROOT_PASSWORD}}`
- `{{MYSQL_USER}}`
- `{{MYSQL_USER_DATABASE}}`
- `{{MYSQL_USER_HOST}}`
- `{{MYSQL_USER_PASSWORD}}`

> *Note:* The backtick "\`" character will need escaping as show in the example.

```
...
  --env "MYSQL_INIT=CREATE DATABASE \`{{MYSQL_USER_DATABASE}}-1\`; GRANT ALL PRIVILEGES ON \`{{MYSQL_USER_DATABASE}}-%\`.* TO '{{MYSQL_USER}}'@'{{MYSQL_USER_HOST}}';" \
...
```

##### MYSQL_ROOT_PASSWORD

On first run the root user is created with an auto-generated password. If you require a specific password,  `MYSQL_ROOT_PASSWORD` can be used when running the container.

```
...
  --env "MYSQL_ROOT_PASSWORD=Passw0rd!" \
...
```

If set to a valid container file path the value will be read from the file - this allows for setting the value securely when combined with an orchestration feature such as Docker Swarm secrets.

```
...
  --env "MYSQL_ROOT_PASSWORD=/run/secrets/mysql_root_password" \
...
```

##### MYSQL_ROOT_PASSWORD_HASHED

To indicate `MYSQL_ROOT_PASSWORD` is a pre-hashed value instead of the default plain-text type set `MYSQL_ROOT_PASSWORD_HASHED` to `true`. When using this option the MySQL root user password will not be stored in the running container so you will need to either add it as a manual step or you will need to supply the password when running `mysql` or `mysqladmin`.

```
...
  --env "MYSQL_ROOT_PASSWORD=*03F7361A0E18DA99361B7A82EA575944F53E206B" \
  --env "MYSQL_ROOT_PASSWORD_HASHED=true" \
...
```

To generate a pre-hashed password use the following MySQL query, substituting `{{password}}` with the required password.

```
$ docker exec mysql.1 \
  mysql -NB \
    -e "SELECT PASSWORD('{{password}}');"
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

If set to a valid container file path the value will be read from the file - this allows for setting the value securely when combined with an orchestration feature such as Docker Swarm secrets.

```
...
  --env "MYSQL_USER_PASSWORD=/run/secrets/mysql_user_password" \
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
