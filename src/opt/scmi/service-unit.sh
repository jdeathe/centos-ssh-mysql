# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
readonly SERVICE_UNIT_ENVIRONMENT_KEYS="
 DOCKER_CONTAINER_OPTS
 DOCKER_IMAGE_PACKAGE_PATH
 DOCKER_IMAGE_TAG
 DOCKER_PORT_MAP_TCP_3306
 ENABLE_MYSQLD_BOOTSTRAP
 ENABLE_MYSQLD_WRAPPER
 MYSQL_INIT_LIMIT
 MYSQL_INIT_SQL
 MYSQL_ROOT_PASSWORD
 MYSQL_ROOT_PASSWORD_HASHED
 MYSQL_SUBNET
 MYSQL_USER
 MYSQL_USER_DATABASE
 MYSQL_USER_PASSWORD
 MYSQL_USER_PASSWORD_HASHED
 SYSTEM_TIMEZONE
"
readonly SERVICE_UNIT_REGISTER_ENVIRONMENT_KEYS="
 REGISTER_ETCD_PARAMETERS
 REGISTER_TTL
 REGISTER_UPDATE_INTERVAL
"

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
SERVICE_UNIT_INSTALL_TIMEOUT="${SERVICE_UNIT_INSTALL_TIMEOUT:-10}"
