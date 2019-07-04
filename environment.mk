# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
DOCKER_IMAGE_NAME := centos-ssh-mysql
DOCKER_IMAGE_RELEASE_TAG_PATTERN := ^[1-2]\.[0-9]+\.[0-9]+$
DOCKER_IMAGE_TAG_PATTERN := ^(latest|[1-2]\.[0-9]+\.[0-9]+)$
DOCKER_USER := jdeathe
SHPEC_ROOT := test/shpec

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
DIST_PATH ?= ./dist
DOCKER_CONTAINER_OPTS ?=
DOCKER_IMAGE_TAG ?= latest
DOCKER_NAME ?= mysql.1
DOCKER_PORT_MAP_TCP_3306 ?= 3306
DOCKER_RESTART_POLICY ?= always
NO_CACHE ?= false
RELOAD_SIGNAL ?= HUP
STARTUP_TIME ?= 10

# ------------------------------------------------------------------------------
# Application container configuration
# ------------------------------------------------------------------------------
ENABLE_MYSQLD_BOOTSTRAP ?= true
ENABLE_MYSQLD_WRAPPER ?= true
MYSQL_INIT_LIMIT ?= 60
MYSQL_INIT_SQL ?=
MYSQL_ROOT_PASSWORD ?=
MYSQL_ROOT_PASSWORD_HASHED ?= false
MYSQL_SUBNET ?= 127.0.0.1
MYSQL_USER ?=
MYSQL_USER_DATABASE ?=
MYSQL_USER_PASSWORD ?=
MYSQL_USER_PASSWORD_HASHED ?= false
SYSTEM_TIMEZONE ?= UTC
