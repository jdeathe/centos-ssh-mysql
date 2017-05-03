readonly BOOTSTRAP_BACKOFF_TIME=10
readonly TEST_DIRECTORY="test"

# These should ideally be a static value but hosts might be using this port so 
# need to allow for alternatives.
DOCKER_PORT_MAP_TCP_22="${DOCKER_PORT_MAP_TCP_22:-NULL}"
DOCKER_PORT_MAP_TCP_3306="${DOCKER_PORT_MAP_TCP_3306:-3306}"

function __destroy ()
{
	local -r private_data_network="bridge_data_internal"
	local -r data_volume_1="mysql.pool-1.1.1.data-mysql"
	local -r data_volume_2="mysql.pool-1.1.2.data-mysql"

	# Destroy the bridge network
	if [[ -n $(docker network ls -q -f name="${private_data_network}") ]]; then
		docker network rm \
			${private_data_network} \
		&> /dev/null
	fi

	# Destroy the data volumes
	if [[ -n $(docker volume ls -q -f name="${data_volume_1}") ]]; then
		docker volume rm \
			${data_volume_1} \
		&> /dev/null
	fi

	if [[ -n $(docker volume ls -q -f name="${data_volume_2}") ]]; then
		docker volume rm \
			${data_volume_2} \
		&> /dev/null
	fi
}

function __setup ()
{
	local -r private_data_network="bridge_data_internal"
	local -r data_volume_1="mysql.pool-1.1.1.data-mysql"
	local -r data_volume_2="mysql.pool-1.1.2.data-mysql"

	# Create the bridge network
	if [[ -z $(docker network ls -q -f name="${private_data_network}") ]]; then
		docker network create \
			--internal \
			--driver bridge \
			--gateway 172.172.40.1 \
			--subnet 172.172.40.0/24 \
			${private_data_network} \
		&> /dev/null
	fi

	# Create the data volumes
	if [[ -z $(docker volume ls -q -f name="${data_volume_1}") ]]; then
		docker volume create \
			--driver local \
			${data_volume_1} \
		&> /dev/null
	fi

	if [[ -z $(docker volume ls -q -f name="${data_volume_2}") ]]; then
		docker volume create \
			--driver local \
			${data_volume_2} \
		&> /dev/null
	fi
}

# Custom shpec matcher
# Match a string with an Extended Regular Expression pattern.
function __shpec_matcher_egrep ()
{
	local pattern="${2:-}"
	local string="${1:-}"

	printf -- \
		'%s' \
		"${string}" \
	| grep -qE -- \
		"${pattern}" \
		-

	assert equal \
		"${?}" \
		0
}

function __terminate_container ()
{
	local container="${1}"

	if docker ps -aq \
		--filter "name=${container}" \
		--filter "status=paused" &> /dev/null; then
		docker unpause ${container} &> /dev/null
	fi

	if docker ps -aq \
		--filter "name=${container}" \
		--filter "status=running" &> /dev/null; then
		docker stop ${container} &> /dev/null
	fi

	if docker ps -aq \
		--filter "name=${container}" &> /dev/null; then
		docker rm -vf ${container} &> /dev/null
	fi
}

function test_basic_operations ()
{
	local -r private_data_network="bridge_data_internal"
	local -r data_volume_1="mysql.pool-1.1.1.data-mysql"
	local container_port_3306=""
	local mysql_root_password=""

	trap "__terminate_container mysql.pool-1.1.1 &> /dev/null; \
		__destroy; \
		exit 1" \
		INT TERM EXIT

	describe "Basic MySQL operations"
		__terminate_container \
			mysql.pool-1.1.1 \
		&> /dev/null

		it "Runs a MySQL container named mysql.pool-1.1.1 on port ${DOCKER_PORT_MAP_TCP_3306}."
			docker run \
				--detach \
				--name mysql.pool-1.1.1 \
				--publish ${DOCKER_PORT_MAP_TCP_3306}:3306 \
				--env "MYSQL_SUBNET=0.0.0.0/0.0.0.0" \
				--env "MYSQL_USER=app-user" \
				--env "MYSQL_USER_PASSWORD=app-password" \
				--env "MYSQL_USER_DATABASE=app-db" \
				--volume ${data_volume_1}:/var/lib/mysql \
				jdeathe/centos-ssh-mysql:latest \
			&> /dev/null

			container_port_3306="$(
				docker port \
					mysql.pool-1.1.1 \
					3306/tcp
			)"
			container_port_3306=${container_port_3306##*:}

			if [[ ${DOCKER_PORT_MAP_TCP_3306} == 0 ]] \
				|| [[ -z ${DOCKER_PORT_MAP_TCP_3306} ]]; then
				assert gt \
					"${container_port_3306}" \
					"30000"
			else
				assert equal \
					"${container_port_3306}" \
					"${DOCKER_PORT_MAP_TCP_3306}"
			fi
		end

		it "Generates a 16 character password for the user root@localhost that can be retreived from logs."
			sleep ${BOOTSTRAP_BACKOFF_TIME}

			mysql_root_password="$(
				docker logs \
					mysql.pool-1.1.1 \
				| grep 'user : root@localhost' \
				| awk -F" : " '{ print $3; }'
			)"

			assert __shpec_matcher_egrep \
				"${mysql_root_password}" \
				"[a-zA-Z0-9]{16}"
		end

		__terminate_container \
			mysql.pool-1.1.1 \
		&> /dev/null
	end

	trap - \
		INT TERM EXIT
}

function test_custom_configuration ()
{
	local -r private_data_network="bridge_data_internal"
	local -r data_volume_2="mysql.pool-1.1.2.data-mysql"
	local show_databases=""

	trap "__terminate_container mysql.pool-1.1.2 &> /dev/null; \
		__terminate_container mysql.pool-1.1.3 &> /dev/null; \
		__destroy; \
		exit 1" \
		INT TERM EXIT

	describe "Customised MySQL configuration"
		__terminate_container \
			mysql.pool-1.1.2 \
		&> /dev/null

		__terminate_container \
			mysql.pool-1.1.3 \
		&> /dev/null

		it "Runs a MySQL server container named mysql.pool-1.1.2 on an internal network."
			docker run \
				--detach \
				--name mysql.pool-1.1.2 \
				--network ${private_data_network} \
				--env "MYSQL_SUBNET=172.172.40.0/255.255.255.0" \
				--env "MYSQL_USER=app-user" \
				--env "MYSQL_USER_PASSWORD=app-password" \
				--env "MYSQL_USER_DATABASE=app-db" \
				--volume ${data_volume_2}:/var/lib/mysql \
				jdeathe/centos-ssh-mysql:latest \
			&> /dev/null

			assert equal \
				"${?}" \
				0
		end

		it "Runs a MySQL client container named mysql.pool-1.1.3 on an internal network."
			# TODO - ISSUE 118: Add option to run as MySQL client only.
			docker run \
				--detach \
				--name mysql.pool-1.1.3 \
				--network ${private_data_network} \
				jdeathe/centos-ssh-mysql:latest \
			&> /dev/null

			assert equal \
				"${?}" \
				0
		end

		sleep ${BOOTSTRAP_BACKOFF_TIME}

		it "Can connect to the MySQL server from a MySQL client on the internal network."
			show_databases="$(
				docker exec \
					-t \
					mysql.pool-1.1.3 \
					mysql \
						-h mysql.pool-1.1.2 \
						-papp-password \
						-uapp-user \
						app-db \
						-e "SHOW DATABASES;" \
				| grep -o 'app-db'
			)"

			assert equal \
				"${show_databases}" \
				"app-db"
		end

		__terminate_container \
			mysql.pool-1.1.2 \
		&> /dev/null

		__terminate_container \
			mysql.pool-1.1.3 \
		&> /dev/null
	end

	trap - \
		INT TERM EXIT
}

if [[ ! -d ${TEST_DIRECTORY} ]]; then
	printf -- \
		"ERROR: Please run from the project root.\n" \
		>&2
	exit 1
fi

describe "jdeathe/centos-ssh-mysql:latest"
	__destroy
	__setup
	test_basic_operations
	test_custom_configuration
	__destroy
end
