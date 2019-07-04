# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
readonly DOCKER_IMAGE_NAME=centos-ssh-mysql
readonly DOCKER_IMAGE_RELEASE_TAG_PATTERN='^[1-2]\.[0-9]+\.[0-9]+$'
readonly DOCKER_IMAGE_TAG_PATTERN='^(latest|[1-2]\.[0-9]+\.[0-9]+)$'
readonly DOCKER_USER=jdeathe

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
DIST_PATH="${DIST_PATH:-./dist}"
DOCKER_CONTAINER_OPTS="${DOCKER_CONTAINER_OPTS:-}"
DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-latest}"
DOCKER_NAME="${DOCKER_NAME:-mysql.1}"
DOCKER_PORT_MAP_TCP_3306="${DOCKER_PORT_MAP_TCP_3306:-3306}"
DOCKER_RESTART_POLICY="${DOCKER_RESTART_POLICY:-always}"
NO_CACHE="${NO_CACHE:-false}"
REGISTER_ETCD_PARAMETERS="${REGISTER_ETCD_PARAMETERS:-}"
REGISTER_TTL="${REGISTER_TTL:-120}"
REGISTER_UPDATE_INTERVAL="${REGISTER_UPDATE_INTERVAL:-95}"
STARTUP_TIME="${STARTUP_TIME:-10}"

# ------------------------------------------------------------------------------
# Application container configuration
# ------------------------------------------------------------------------------
ENABLE_MYSQLD_BOOTSTRAP="${ENABLE_MYSQLD_BOOTSTRAP:-true}"
ENABLE_MYSQLD_WRAPPER="${ENABLE_MYSQLD_WRAPPER:-true}"
MYSQL_INIT_LIMIT="${MYSQL_INIT_LIMIT:-60}"
MYSQL_INIT_SQL="${MYSQL_INIT_SQL:-}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"
MYSQL_ROOT_PASSWORD_HASHED="${MYSQL_ROOT_PASSWORD_HASHED:-false}"
MYSQL_SUBNET="${MYSQL_SUBNET:-127.0.0.1}"
MYSQL_USER="${MYSQL_USER:-}"
MYSQL_USER_DATABASE="${MYSQL_USER_DATABASE:-}"
MYSQL_USER_PASSWORD="${MYSQL_USER_PASSWORD:-}"
MYSQL_USER_PASSWORD_HASHED="${MYSQL_USER_PASSWORD_HASHED:-false}"
SYSTEM_TIMEZONE="${SYSTEM_TIMEZONE:-UTC}"
