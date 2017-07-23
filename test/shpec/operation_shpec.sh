readonly STARTUP_TIME=7
readonly TEST_DIRECTORY="test"

# These should ideally be a static value but hosts might be using this port so 
# need to allow for alternatives.
DOCKER_PORT_MAP_TCP_22="${DOCKER_PORT_MAP_TCP_22:-NULL}"
DOCKER_PORT_MAP_TCP_3306="${DOCKER_PORT_MAP_TCP_3306:-3306}"

function __destroy ()
{
	local -r private_network_1="bridge_internal_1"
	local -r private_network_2="bridge_internal_2"
	local -r data_volume_1="mysql.pool-1.1.2.data-mysql"
	local -r data_volume_2="mysql.pool-1.1.4.data-mysql"

	# Destroy the bridge networks
	if [[ -n $(docker network ls -q -f name="${private_network_1}") ]]; then
		docker network rm \
			${private_network_1} \
		&> /dev/null
	fi

	if [[ -n $(docker network ls -q -f name="${private_network_2}") ]]; then
		docker network rm \
			${private_network_2} \
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

function __get_container_port ()
{
	local container="${1:-}"
	local port="${2:-}"
	local value=""

	value="$(
		docker port \
			${container} \
			${port}
	)"
	value=${value##*:}

	printf -- \
		'%s' \
		"${value}"
}

# container - Docker container name.
# counter - Timeout counter in seconds.
# process_pattern - Regular expression pattern used to match running process.
# bootstrap_lock_file - Path to the bootstrap lock file.
function __is_container_ready ()
{
	local bootstrap_lock_file="${4:-}"
	local container="${1:-}"
	local counter=$(
		awk \
			-v seconds="${2:-10}" \
			'BEGIN { print 10 * seconds; }'
	)
	local process_pattern="${3:-}"

	until (( counter == 0 )); do
		sleep 0.1

		if docker exec ${container} \
				bash -c "ps axo command" \
			| grep -qE "${process_pattern}" \
			> /dev/null 2>&1 \
			&& docker exec ${container} \
				bash -c "[[ ! -e ${bootstrap_lock_file} ]]"
		then
			break
		fi

		(( counter -= 1 ))
	done

	if (( counter == 0 )); then
		return 1
	fi

	return 0
}

function __setup ()
{
	local -r private_network_1="bridge_internal_1"
	local -r private_network_2="bridge_internal_2"
	local -r data_volume_1="mysql.pool-1.1.2.data-mysql"
	local -r data_volume_2="mysql.pool-1.1.4.data-mysql"

	# Create the bridge networks
	if [[ -z $(docker network ls -q -f name="${private_network_1}") ]]; then
		docker network create \
			--internal \
			--driver bridge \
			--gateway 172.172.40.1 \
			--subnet 172.172.40.0/24 \
			${private_network_1} \
		&> /dev/null
	fi

	if [[ -z $(docker network ls -q -f name="${private_network_2}") ]]; then
		docker network create \
			--internal \
			--driver bridge \
			--gateway 172.172.42.1 \
			--subnet 172.172.42.0/24 \
			${private_network_2} \
		&> /dev/null
	fi

	# Create the data volumes
	if [[ -z $(docker volume ls -q -f name="${data_volume_1}") ]]; then
		docker volume create \
			--driver local \
			${data_volume_1} \
		&> /dev/null
	fi

	if [[ -n $(docker volume ls -q -f name="${data_volume_2}") ]]; then
		docker volume rm \
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
	local -r private_network_1="bridge_internal_1"
	local container_port_3306=""
	local mysql_root_password=""
	local select_users=""
	local show_databases=""
	local show_grants=""

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
				jdeathe/centos-ssh-mysql:latest \
			&> /dev/null

			container_port_3306="$(
				__get_container_port \
					mysql.pool-1.1.1 \
					3306/tcp
			)"

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

		if ! __is_container_ready \
			mysql.pool-1.1.1 \
			${STARTUP_TIME} \
			"/usr/libexec/mysqld " \
			"/var/lock/subsys/mysqld-bootstrap.lock"; then
			exit 1
		fi

		it "Generates a 16 character password for the user root@localhost that can be retreived from logs."
			mysql_root_password="$(
				docker logs \
					mysql.pool-1.1.1 \
				| grep 'user : root@localhost' \
				| sed -e 's~^.*,.*password : \([a-zA-Z0-9]*\).*$~\1~'
			)"

			assert __shpec_matcher_egrep \
				"${mysql_root_password}" \
				"[a-zA-Z0-9]{16}"
		end

		it "Removes test databases and does not create a database by default."
			show_databases="$(
				docker exec \
					mysql.pool-1.1.1 \
					mysql \
						--batch \
						--password=${mysql_root_password} \
						--skip-column-names \
						--user=root \
						-e "SHOW DATABASES;"
			)"

			assert equal \
				"${show_databases}" \
				"$(
					printf -- \
						'%s\n%s' \
						'information_schema' \
						'mysql'
				)"

			it "Shows the database as N/A in the MySQL Details log output."
				docker logs \
					mysql.pool-1.1.1 \
				| grep -q 'database : N/A' \
				&> /dev/null

				assert equal \
					"${?}" \
					0
			end
		end

		it "Limits root user to access from localhost."
			select_users="$(
				docker exec \
					mysql.pool-1.1.1 \
					mysql \
						--batch \
						--password=${mysql_root_password} \
						--skip-column-names \
						--user=root \
						-e "SELECT User, Host from mysql.user;"
			)"

			assert equal \
				"${select_users}" \
				"$(
					printf -- \
						'%s\t%s' \
						'root' \
						'localhost'
				)"
		end

		it "Allows for creation of a database on first run (e.g my-db)."
			__terminate_container \
				mysql.pool-1.1.1 \
			&> /dev/null

			docker run \
				--detach \
				--name mysql.pool-1.1.1 \
				--env "MYSQL_ROOT_PASSWORD=mypasswd" \
				--env "MYSQL_USER_DATABASE=my-db" \
				jdeathe/centos-ssh-mysql:latest \
			&> /dev/null

			if ! __is_container_ready \
				mysql.pool-1.1.1 \
				${STARTUP_TIME} \
				"/usr/libexec/mysqld " \
				"/var/lock/subsys/mysqld-bootstrap.lock"; then
				exit 1
			fi

			docker exec \
				-t \
				mysql.pool-1.1.1 \
				mysql \
					-pmypasswd \
					-uroot \
					-e "USE my-db;" \
			&> /dev/null

			assert equal \
				"${?}" \
				0

			it "Shows the database name in the MySQL Details log output."
				docker logs \
					mysql.pool-1.1.1 \
				| grep -q 'database : my-db' \
				&> /dev/null

				assert equal \
					"${?}" \
					0
			end
		end

		it "Allows for creation of a user on first run (e.g my-user@'localhost')."
			__terminate_container \
				mysql.pool-1.1.1 \
			&> /dev/null

			docker run \
				--detach \
				--name mysql.pool-1.1.1 \
				--env "MYSQL_ROOT_PASSWORD=mypasswd" \
				--env "MYSQL_USER=my-user" \
				jdeathe/centos-ssh-mysql:latest \
			&> /dev/null

			if ! __is_container_ready \
				mysql.pool-1.1.1 \
				${STARTUP_TIME} \
				"/usr/libexec/mysqld " \
				"/var/lock/subsys/mysqld-bootstrap.lock"; then
				exit 1
			fi

			select_users="$(
				docker exec \
					mysql.pool-1.1.1 \
					mysql \
						--batch \
						--password=mypasswd \
						--skip-column-names \
						--user=root \
						-e "SELECT User, Host from mysql.user ORDER BY User ASC;"
			)"

			assert equal \
				"${select_users}" \
				"$(
					printf -- \
						'%s\t%s\n%s\t%s' \
						'my-user' \
						'localhost' \
						'root' \
						'localhost'
				)"

			it "Shows the user in the MySQL Details log output."
				docker logs \
					mysql.pool-1.1.1 \
				| grep -q 'user : my-user@localhost' \
				&> /dev/null

				assert equal \
					"${?}" \
					0
			end

			it "Grants the user USAGE privileges."
				show_grants="$(
					docker exec \
						mysql.pool-1.1.1 \
						mysql \
							--batch \
							--password=mypasswd \
							--skip-column-names \
							--user=root \
							-e "SHOW GRANTS FOR 'my-user'@'localhost';"
				)"

				assert __shpec_matcher_egrep \
					"${show_grants}" \
					"^GRANT USAGE ON \*\.\* TO 'my-user'@'localhost' IDENTIFIED BY PASSWORD '[\*A-Z0-9]+'$"
			end
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
	local -r data_volume_1="mysql.pool-1.1.2.data-mysql"
	local -r data_volume_2="mysql.pool-1.1.4.data-mysql"
	local -r private_network_1="bridge_internal_1"
	local -r private_network_2="bridge_internal_2"
	local -r redacted_value="********"
	local -r mysql_root_password="MyR00tpA55w*rd"
	local -r mysql_root_password_hash="*18016D83960C9DBA9FF71F4D0DA05DAF4FEC7639"
	local -r mysql_user_password="MyUs3rpA55w*rd!"
	local -r mysql_user_password_hash="*618F42F5226FDCAF0BD92F8CE38E9CCD52D51E4D"
	local mysql_root_password_log=""
	local mysql_user_password_log=""
	local select_users=""
	local show_databases=""

	trap "__terminate_container mysql.pool-1.1.2 &> /dev/null; \
		__terminate_container mysql.pool-1.1.3 &> /dev/null; \
		__terminate_container mysql.pool-1.1.4 &> /dev/null; \
		__terminate_container mysql.pool-1.1.5 &> /dev/null; \
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

		__terminate_container \
			mysql.pool-1.1.4 \
		&> /dev/null

		__terminate_container \
			mysql.pool-1.1.5 \
		&> /dev/null

		it "Runs a MySQL server container named mysql.pool-1.1.2 on an internal network."
			docker run \
				--detach \
				--name mysql.pool-1.1.2 \
				--network-alias mysql.pool-1.1.2 \
				--network ${private_network_1} \
				--env "MYSQL_ROOT_PASSWORD=${mysql_root_password_hash}" \
				--env "MYSQL_ROOT_PASSWORD_HASHED=true" \
				--env "MYSQL_SUBNET=172.172.40.0/255.255.255.0" \
				--env "MYSQL_USER=app-user" \
				--env "MYSQL_USER_PASSWORD=${mysql_user_password}" \
				--env "MYSQL_USER_DATABASE=app-db" \
				--volume ${data_volume_1}:/var/lib/mysql \
				jdeathe/centos-ssh-mysql:latest \
			&> /dev/null

			assert equal \
				"${?}" \
				0

			it "Runs a MySQL client container named mysql.pool-1.1.3 on an internal network."
				# TODO - ISSUE 118: Add option to run as MySQL client only.
				docker run \
					--detach \
					--name mysql.pool-1.1.3 \
					--network ${private_network_1} \
					jdeathe/centos-ssh-mysql:latest \
				&> /dev/null

				assert equal \
					"${?}" \
					0
			end

			if ! __is_container_ready \
				mysql.pool-1.1.2 \
				${STARTUP_TIME} \
				"/usr/libexec/mysqld " \
				"/var/lock/subsys/mysqld-bootstrap.lock"; then
				exit 1
			fi

			it "Shows the database name in the MySQL Details log output."
				docker logs \
					mysql.pool-1.1.2 \
				| grep -q 'database : app-db' \
				&> /dev/null

				assert equal \
					"${?}" \
					0
			end

			it "Redacts operator supplied root password from the log output."
				mysql_root_password_log="$(
					docker logs \
						mysql.pool-1.1.2 \
					| grep 'user : root@localhost' \
					| sed -e 's~^.*,.*password : \([^ ,:]*\).*$~\1~'
				)"

				assert equal \
					"${mysql_root_password_log}" \
					"********"
			end

			it "Redacts operator supplied user password from the log output."
				mysql_user_password_log="$(
					docker logs \
						mysql.pool-1.1.2 \
					| grep 'user : app-user@172.172.40.0/255.255.255.0' \
					| sed -e 's~^.*,.*password : \([^ ,:]*\).*$~\1~'
				)"

				assert equal \
					"${mysql_user_password_log}" \
					"********"
			end

			it "Creates a single user named app-user, restricted to a subnet."
				select_users="$(
					docker exec \
						mysql.pool-1.1.2 \
						mysql \
							--batch \
							--password=${mysql_root_password} \
							--skip-column-names \
							--user=root \
							-e "SELECT User, Host from mysql.user ORDER BY User ASC;"
				)"

				assert equal \
					"${select_users}" \
					"$(
						printf -- \
							'%s\t%s\n%s\t%s' \
							'app-user' \
							'172.172.40.0/255.255.255.0' \
							'root' \
							'localhost'
					)"
			end

			if ! __is_container_ready \
				mysql.pool-1.1.3 \
				${STARTUP_TIME} \
				"/usr/libexec/mysqld " \
				"/var/lock/subsys/mysqld-bootstrap.lock"; then
				exit 1
			fi

			it "Can connect to the MySQL server from a MySQL client on an internal network."
				show_databases="$(
					docker exec \
						-t \
						mysql.pool-1.1.3 \
						mysql \
							-h mysql.pool-1.1.2 \
							-p${mysql_user_password} \
							-uapp-user \
							app-db \
							-e "SHOW DATABASES;" \
					| grep -o 'app-db'
				)"

				assert equal \
					"${show_databases}" \
					"app-db"
			end
		end

		it "Runs a MySQL server container named mysql.pool-1.1.4 on multiple internal networks."
			docker create \
				--name mysql.pool-1.1.4 \
				--network ${private_network_1} \
				--env "MYSQL_ROOT_PASSWORD=${mysql_root_password_hash}" \
				--env "MYSQL_ROOT_PASSWORD_HASHED=true" \
				--env "MYSQL_SUBNET=0.0.0.0/0.0.0.0" \
				--env "MYSQL_USER=app2-user" \
				--env "MYSQL_USER_PASSWORD=${mysql_user_password_hash}" \
				--env "MYSQL_USER_PASSWORD_HASHED=true" \
				--env "MYSQL_USER_DATABASE=app2-db" \
				--volume ${data_volume_2}:/var/lib/mysql \
				jdeathe/centos-ssh-mysql:latest \
			&> /dev/null

			docker network connect \
				${private_network_2} \
				mysql.pool-1.1.4 \
			&> /dev/null

			docker start \
				mysql.pool-1.1.4 \
			&> /dev/null

			assert equal \
				"${?}" \
				0

			it "Runs a MySQL client container named mysql.pool-1.1.5 on an internal network."
				# TODO - ISSUE 118: Add option to run as MySQL client only.
				docker run \
					--detach \
					--name mysql.pool-1.1.5 \
					--network ${private_network_2} \
					jdeathe/centos-ssh-mysql:latest \
				&> /dev/null

				assert equal \
					"${?}" \
					0
			end

			if ! __is_container_ready \
				mysql.pool-1.1.4 \
				${STARTUP_TIME} \
				"/usr/libexec/mysqld " \
				"/var/lock/subsys/mysqld-bootstrap.lock"; then
				exit 1
			fi

			if ! __is_container_ready \
				mysql.pool-1.1.5 \
				${STARTUP_TIME} \
				"/usr/libexec/mysqld " \
				"/var/lock/subsys/mysqld-bootstrap.lock"; then
				exit 1
			fi

			it "Creates a single user named app-user, unrestricted by subnet."
				select_users="$(
					docker exec \
						mysql.pool-1.1.4 \
						mysql \
							--batch \
							--password=${mysql_root_password} \
							--skip-column-names \
							--user=root \
							-e "SELECT User, Host from mysql.user ORDER BY User ASC;"
				)"

				assert equal \
					"${select_users}" \
					"$(
						printf -- \
							'%s\t%s\n%s\t%s' \
							'app2-user' \
							'%' \
							'root' \
							'localhost'
					)"
			end

			it "Can connect to the MySQL server from MySQL client's on both internal networks."
				show_databases="$(
					docker exec \
						-t \
						mysql.pool-1.1.5 \
						mysql \
							-h mysql.pool-1.1.4 \
							-p${mysql_user_password} \
							-uapp2-user \
							app2-db \
							-e "SHOW DATABASES;" \
					| grep -o 'app2-db'
				)"

				show_databases+=":"

				show_databases+="$(
					docker exec \
						-t \
						mysql.pool-1.1.3 \
						mysql \
							-h mysql.pool-1.1.4 \
							-p${mysql_user_password} \
							-uapp2-user \
							app2-db \
							-e "SHOW DATABASES;" \
					| grep -o 'app2-db'
				)"

				assert equal \
					"${show_databases}" \
					"app2-db:app2-db"
			end
		end

		__terminate_container \
			mysql.pool-1.1.2 \
		&> /dev/null

		__terminate_container \
			mysql.pool-1.1.3 \
		&> /dev/null

		__terminate_container \
			mysql.pool-1.1.4 \
		&> /dev/null

		__terminate_container \
			mysql.pool-1.1.5 \
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
