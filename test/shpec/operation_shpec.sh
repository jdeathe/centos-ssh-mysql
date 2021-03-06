readonly STARTUP_TIME=10
readonly TEST_DIRECTORY="test"

# These should ideally be a static value but hosts might be using this port so 
# need to allow for alternatives.
DOCKER_PORT_MAP_TCP_3306="${DOCKER_PORT_MAP_TCP_3306:-3306}"

function __destroy ()
{
	local -r private_network_1="bridge_internal_1"
	local -r private_network_2="bridge_internal_2"
	local -r data_volume_1="mysql.2.data-mysql"
	local -r data_volume_2="mysql.4.data-mysql"
	local -r data_volume_3="mysql.6.data-mysql"

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

	if [[ -n $(docker volume ls -q -f name="${data_volume_3}") ]]; then
		docker volume rm \
			${data_volume_3} \
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
# ready_test - Command used to test if the service is ready.
function __is_container_ready ()
{
	local container="${1:-}"
	local counter=$(
		awk \
			-v seconds="${2:-10}" \
			'BEGIN { print 10 * seconds; }'
	)
	local process_pattern="${3:-}"
	local ready_test="${4:-true}"

	until (( counter == 0 )); do
		sleep 0.1

		if docker exec ${container} \
			bash -c "ps axo command \
				| grep -qE \"${process_pattern}\" \
				&& eval \"${ready_test}\"" \
			&> /dev/null
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

function __reset_data_volume ()
{
	local -r data_volume_1="mysql.2.data-mysql"
	local -r data_volume_2="mysql.4.data-mysql"
	local -r data_volume_3="mysql.6.data-mysql"

	local group="${1:-1}"

	case "${group}" in
		3)
			# Destroy the data volume
			if [[ -n $(docker volume ls -q -f name="${data_volume_3}") ]]; then
				docker volume rm \
					${data_volume_3} \
				&> /dev/null
			fi

			# Create the data volume
			if [[ -z $(docker volume ls -q -f name="${data_volume_3}") ]]; then
				docker volume create \
					--driver local \
					${data_volume_3} \
				&> /dev/null
			fi
			;;
		2)
			# Destroy the data volume
			if [[ -n $(docker volume ls -q -f name="${data_volume_2}") ]]; then
				docker volume rm \
					${data_volume_2} \
				&> /dev/null
			fi

			# Create the data volume
			if [[ -z $(docker volume ls -q -f name="${data_volume_2}") ]]; then
				docker volume create \
					--driver local \
					${data_volume_2} \
				&> /dev/null
			fi
			;;
		*)
			# Destroy the data volume
			if [[ -n $(docker volume ls -q -f name="${data_volume_1}") ]]; then
				docker volume rm \
					${data_volume_1} \
				&> /dev/null
			fi

			# Create the data volume
			if [[ -z $(docker volume ls -q -f name="${data_volume_1}") ]]; then
				docker volume create \
					--driver local \
					${data_volume_1} \
				&> /dev/null
			fi
			;;
		esac
}

function __setup ()
{
	local -r private_network_1="bridge_internal_1"
	local -r private_network_2="bridge_internal_2"
	local -r data_volume_1="mysql.2.data-mysql"
	local -r data_volume_2="mysql.4.data-mysql"
	local -r data_volume_3="mysql.6.data-mysql"

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

	if [[ -n $(docker volume ls -q -f name="${data_volume_3}") ]]; then
		docker volume rm \
			${data_volume_3} \
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

	trap "__terminate_container mysql.1 &> /dev/null; \
		__destroy; \
		exit 1" \
		INT TERM EXIT

	describe "Basic MySQL operations"
		describe "Runs named container"
			__terminate_container \
				mysql.1 \
			&> /dev/null

			it "Can publish ${DOCKER_PORT_MAP_TCP_3306}:3306."
				docker run \
					--detach \
					--name mysql.1 \
					--publish ${DOCKER_PORT_MAP_TCP_3306}:3306 \
					jdeathe/centos-ssh-mysql:latest \
				&> /dev/null

				container_port_3306="$(
					__get_container_port \
						mysql.1 \
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
		end

		if ! __is_container_ready \
			mysql.1 \
			${STARTUP_TIME} \
			"/usr/sbin/mysqld " \
			"[[ -e /var/lib/mysql/ibdata1 ]] \
				&& [[ ! -e /var/lock/subsys/mysqld-bootstrap ]] \
				&& [[ -s /var/run/mysqld/mysqld.pid ]]"
		then
			exit 1
		fi

		describe "Default initialisation"
			describe "Setup of root user"
				it "Redacts password in logs output."
					mysql_root_password="$(
						docker logs \
							mysql.1 \
							2> /dev/null \
						| grep 'user : root@localhost' \
						| sed -e 's~^.*,.*password : \([^ ,:]*\).*$~\1~'
					)"

					assert equal \
						"${mysql_root_password}" \
						"********"
				end

				it "Limits access to localhost only."
					select_users="$(
						docker exec \
							mysql.1 \
							mysql \
								--batch \
								--skip-column-names \
								--user=root \
								-e "SELECT User, Host from mysql.user;"
					)"

					assert equal \
						"${select_users}" \
						"$(
							printf -- \
								'%s\t%s\n%s\t%s\n%s\t%s' \
								'mysql.session' \
								'localhost' \
								'mysql.sys' \
								'localhost' \
								'root' \
								'localhost'
						)"
				end
			end

			describe "Database setup"
				it "Removes all but the necessary databases."
					show_databases="$(
						docker exec \
							mysql.1 \
							mysql \
								--batch \
								--skip-column-names \
								--user=root \
								-e "SHOW DATABASES;"
					)"

					assert equal \
						"${show_databases}" \
						"$(
							printf -- \
								'%s\n%s\n%s\n%s' \
								'information_schema' \
								'mysql' \
								'performance_schema' \
								'sys'
						)"
				end

				it "Shows N/A in MySQL Details."
					docker logs \
						mysql.1 \
						2> /dev/null \
					| grep -q 'database : N/A' \
					&> /dev/null

					assert equal \
						"${?}" \
						0
				end
			end
		end

		describe "Database setup"
			it "Creates a database on first run."
				__terminate_container \
					mysql.1 \
				&> /dev/null

				docker run \
					--detach \
					--name mysql.1 \
					--env "MYSQL_ROOT_PASSWORD=mypasswd" \
					--env "MYSQL_USER_DATABASE=my-db" \
					jdeathe/centos-ssh-mysql:latest \
				&> /dev/null

				if ! __is_container_ready \
					mysql.1 \
					${STARTUP_TIME} \
					"/usr/sbin/mysqld " \
					"[[ -e /var/lib/mysql/ibdata1 ]] \
						&& [[ ! -e /var/lock/subsys/mysqld-bootstrap ]] \
						&& [[ -s /var/run/mysqld/mysqld.pid ]]"
				then
					exit 1
				fi

				docker exec \
					-t \
					mysql.1 \
					mysql \
						-uroot \
						-e "USE my-db;" \
				&> /dev/null

				assert equal \
					"${?}" \
					0
			end

			it "Has database name in MySQL Details."
				docker logs \
					mysql.1 \
					2> /dev/null \
				| grep -q 'database : my-db' \
				&> /dev/null

				assert equal \
					"${?}" \
					0
			end
		end

		describe "User setup"
			it "Creates a user on first run."
				__terminate_container \
					mysql.1 \
				&> /dev/null

				docker run \
					--detach \
					--name mysql.1 \
					--env "MYSQL_ROOT_PASSWORD=mypasswd" \
					--env "MYSQL_USER=my-user" \
					jdeathe/centos-ssh-mysql:latest \
				&> /dev/null

				if ! __is_container_ready \
					mysql.1 \
					${STARTUP_TIME} \
					"/usr/sbin/mysqld " \
					"[[ -e /var/lib/mysql/ibdata1 ]] \
						&& [[ ! -e /var/lock/subsys/mysqld-bootstrap ]] \
						&& [[ -s /var/run/mysqld/mysqld.pid ]]"
				then
					exit 1
				fi

				select_users="$(
					docker exec \
						mysql.1 \
						mysql \
							--batch \
							--skip-column-names \
							--user=root \
							-e "SELECT User, Host from mysql.user ORDER BY User ASC;"
				)"

				assert equal \
					"${select_users}" \
					"$(
						printf -- \
							'%s\t%s\n%s\t%s\n%s\t%s\n%s\t%s' \
							'my-user' \
							'localhost' \
							'mysql.session' \
							'localhost' \
							'mysql.sys' \
							'localhost' \
							'root' \
							'localhost'
					)"
			end

			it "Has user in MySQL Details."
				docker logs \
					mysql.1 \
					2> /dev/null \
				| grep -q 'user : my-user@localhost' \
				&> /dev/null

				assert equal \
					"${?}" \
					0
			end

			it "Grants the user USAGE privileges."
				show_grants="$(
					docker exec \
						mysql.1 \
						mysql \
							--batch \
							--skip-column-names \
							--user=root \
							-e "SHOW GRANTS FOR 'my-user'@'localhost';"
				)"

				assert __shpec_matcher_egrep \
					"${show_grants}" \
					"^GRANT USAGE ON \*\.\* TO 'my-user'@'localhost'$"
			end
		end

		__terminate_container \
			mysql.1 \
		&> /dev/null
	end

	trap - \
		INT TERM EXIT
}

function test_custom_configuration ()
{
	local -r data_volume_1="mysql.2.data-mysql"
	local -r data_volume_2="mysql.4.data-mysql"
	local -r data_volume_3="mysql.6.data-mysql"
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
	local show_tables=""

	trap "__terminate_container mysql.2 &> /dev/null; \
		__terminate_container mysql.3 &> /dev/null; \
		__terminate_container mysql.4 &> /dev/null; \
		__terminate_container mysql.5 &> /dev/null; \
		__terminate_container mysql.6 &> /dev/null; \
		__terminate_container mysql.7 &> /dev/null; \
		__destroy; \
		exit 1" \
		INT TERM EXIT

	describe "Customised MySQL configuration"
		__terminate_container \
			mysql.2 \
		&> /dev/null

		__terminate_container \
			mysql.3 \
		&> /dev/null

		describe "Single internal network"
			it "Runs a named server container."
				docker run \
					--detach \
					--name mysql.2 \
					--network-alias mysql.2 \
					--network ${private_network_1} \
					--env "MYSQL_ROOT_PASSWORD=${mysql_root_password}" \
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
			end

			it "Runs a named client container."
				docker run \
					--detach \
					--name mysql.3 \
					--network ${private_network_1} \
					--env "ENABLE_MYSQLD_BOOTSTRAP=false" \
					--env "ENABLE_MYSQLD_WRAPPER=false" \
					jdeathe/centos-ssh-mysql:latest \
				&> /dev/null

				assert equal \
					"${?}" \
					0
			end

			if ! __is_container_ready \
				mysql.2 \
				${STARTUP_TIME} \
				"/usr/sbin/mysqld " \
				"[[ -e /var/lib/mysql/ibdata1 ]] \
					&& [[ ! -e /var/lock/subsys/mysqld-bootstrap ]] \
					&& [[ -s /var/run/mysqld/mysqld.pid ]]"
			then
				exit 1
			fi

			describe "MySQL Details log output"
				it "Has the database name."
					docker logs \
						mysql.2 \
						2> /dev/null \
					| grep -q 'database : app-db' \
					&> /dev/null

					assert equal \
						"${?}" \
						0
				end

				describe "Radact operator supplied passwords"
					it "Redacts root password."
						mysql_root_password_log="$(
							docker logs \
								mysql.2 \
								2> /dev/null \
							| grep 'user : root@localhost' \
							| sed -e 's~^.*,.*password : \([^ ,:]*\).*$~\1~'
						)"

						assert equal \
							"${mysql_root_password_log}" \
							"********"
					end

					it "Redacts user password."
						mysql_user_password_log="$(
							docker logs \
								mysql.2 \
								2> /dev/null \
							| grep 'user : app-user@172.172.40.0/255.255.255.0' \
							| sed -e 's~^.*,.*password : \([^ ,:]*\).*$~\1~'
						)"

						assert equal \
							"${mysql_user_password_log}" \
							"********"
					end
				end
			end

			describe "User creation"
				it "Creates a subnet restricted user."
					select_users="$(
						docker exec \
							mysql.2 \
							mysql \
								--batch \
								--skip-column-names \
								--user=root \
								-e "SELECT User, Host from mysql.user ORDER BY User ASC;"
					)"

					assert equal \
						"${select_users}" \
						"$(
							printf -- \
								'%s\t%s\n%s\t%s\n%s\t%s\n%s\t%s' \
								'app-user' \
								'172.172.40.0/255.255.255.0' \
								'mysql.session' \
								'localhost' \
								'mysql.sys' \
								'localhost' \
								'root' \
								'localhost'
						)"
				end
			end

			describe "Client to server connection"
				it "Can successfully connect."
					show_databases="$(
						docker exec \
							-t \
							mysql.3 \
							mysql \
								-h mysql.2 \
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

			# Clean up server but keep client running.
			__terminate_container \
				mysql.2 \
			&> /dev/null
		end

		describe "File path passwords"
			select_users=""
			show_databases=""

			# Reset to clear data volume
			__reset_data_volume 1

			it "Runs a named server container."
				docker run \
					--detach \
					--name mysql.2 \
					--network-alias mysql.2 \
					--network ${private_network_1} \
					--env "MYSQL_ROOT_PASSWORD=/var/run/secrets/mysql_root_password" \
					--env "MYSQL_SUBNET=172.172.40.0/255.255.255.0" \
					--env "MYSQL_USER=app-user" \
					--env "MYSQL_USER_PASSWORD=/var/run/secrets/mysql_user_password" \
					--env "MYSQL_USER_DATABASE=app-db" \
					--volume ${data_volume_1}:/var/lib/mysql \
					--volume ${PWD}/${TEST_DIRECTORY}/fixture/secrets:/var/run/secrets:ro \
					jdeathe/centos-ssh-mysql:latest \
				&> /dev/null

				assert equal \
					"${?}" \
					0
			end

			if ! __is_container_ready \
				mysql.2 \
				${STARTUP_TIME} \
				"/usr/sbin/mysqld " \
				"[[ -e /var/lib/mysql/ibdata1 ]] \
					&& [[ ! -e /var/lock/subsys/mysqld-bootstrap ]] \
					&& [[ -s /var/run/mysqld/mysqld.pid ]]"
			then
				exit 1
			fi

			describe "Root password"
				it "Creates a subnet restricted user."
					select_users="$(
						docker exec \
							mysql.2 \
							mysql \
								--batch \
								--skip-column-names \
								--user=root \
								-e "SELECT User, Host from mysql.user ORDER BY User ASC;"
					)"

					assert equal \
						"${select_users}" \
						"$(
							printf -- \
								'%s\t%s\n%s\t%s\n%s\t%s\n%s\t%s' \
								'app-user' \
								'172.172.40.0/255.255.255.0' \
								'mysql.session' \
								'localhost' \
								'mysql.sys' \
								'localhost' \
								'root' \
								'localhost'
						)"
				end
			end

			describe "Client password"
				it "Can successfully connect."
					show_databases="$(
						docker exec \
							-t \
							mysql.3 \
							mysql \
								-h mysql.2 \
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

			# Clean up server but keep client running.
			__terminate_container \
				mysql.2 \
			&> /dev/null
		end

		describe "File path hashed passwords"
			select_users=""
			show_databases=""

			# Reset to clear data volume
			__reset_data_volume 1

			it "Runs a named server container."
				docker run \
					--detach \
					--name mysql.2 \
					--network-alias mysql.2 \
					--network ${private_network_1} \
					--env "MYSQL_ROOT_PASSWORD=/var/run/secrets/mysql_root_password_hashed" \
					--env "MYSQL_ROOT_PASSWORD_HASHED=true" \
					--env "MYSQL_SUBNET=172.172.40.0/255.255.255.0" \
					--env "MYSQL_USER=app-user" \
					--env "MYSQL_USER_PASSWORD=/var/run/secrets/mysql_user_password_hashed" \
					--env "MYSQL_USER_PASSWORD_HASHED=true" \
					--env "MYSQL_USER_DATABASE=app-db" \
					--volume ${data_volume_1}:/var/lib/mysql \
					--volume ${PWD}/${TEST_DIRECTORY}/fixture/secrets:/var/run/secrets:ro \
					jdeathe/centos-ssh-mysql:latest \
				&> /dev/null

				assert equal \
					"${?}" \
					0
			end

			if ! __is_container_ready \
				mysql.2 \
				${STARTUP_TIME} \
				"/usr/sbin/mysqld " \
				"[[ -e /var/lib/mysql/ibdata1 ]] \
					&& [[ ! -e /var/lock/subsys/mysqld-bootstrap ]] \
					&& [[ -s /var/run/mysqld/mysqld.pid ]]"
			then
				exit 1
			fi

			describe "Root password"
				it "Creates a subnet restricted user."
					# Set MySQL root password
					if docker exec mysql.2 bash command -v mysql_config_editor &> /dev/null
					then
						docker exec -i mysql.2 sshpass mysql_config_editor set --skip-warn --password \
							< ${PWD}/${TEST_DIRECTORY}/fixture/secrets/mysql_root_password
					else
						docker exec mysql.2 bash -c "printf -- '[client]\npassword={{MYSQL_ROOT_PASSWORD}}\n' > /root/.my.cnf"
						docker exec mysql.2 chown 0:0 /root/.my.cnf
						docker exec mysql.2 chmod 0600 /root/.my.cnf
						docker exec -i mysql.2 bash -c "IFS= read -r mysql_root_password; sed -i -e \"s~{{MYSQL_ROOT_PASSWORD}}~\${mysql_root_password}~g\" /root/.my.cnf;" \
							< ${PWD}/${TEST_DIRECTORY}/fixture/secrets/mysql_root_password
					fi

					select_users="$(
						docker exec \
							mysql.2 \
							mysql \
								--batch \
								--skip-column-names \
								--user=root \
								-e "SELECT User, Host from mysql.user ORDER BY User ASC;"
					)"

					assert equal \
						"${select_users}" \
						"$(
							printf -- \
								'%s\t%s\n%s\t%s\n%s\t%s\n%s\t%s' \
								'app-user' \
								'172.172.40.0/255.255.255.0' \
								'mysql.session' \
								'localhost' \
								'mysql.sys' \
								'localhost' \
								'root' \
								'localhost'
						)"
				end
			end

			describe "Client password"
				it "Can successfully connect."
					show_databases="$(
						docker exec \
							-t \
							mysql.3 \
							mysql \
								-h mysql.2 \
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

			# Clean up server but keep client running.
			__terminate_container \
				mysql.2 \
			&> /dev/null
		end

		describe "Multiple internal networks"
			__terminate_container \
				mysql.4 \
			&> /dev/null

			__terminate_container \
				mysql.5 \
			&> /dev/null

			it "Runs a named server container."
				docker create \
					--name mysql.4 \
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
					mysql.4 \
				&> /dev/null

				docker start \
					mysql.4 \
				&> /dev/null

				assert equal \
					"${?}" \
					0
			end

			it "Runs a named client container."
				docker run \
					--detach \
					--name mysql.5 \
					--network ${private_network_2} \
					--env "ENABLE_MYSQLD_BOOTSTRAP=false" \
					--env "ENABLE_MYSQLD_WRAPPER=false" \
					jdeathe/centos-ssh-mysql:latest \
				&> /dev/null

				assert equal \
					"${?}" \
					0
			end

			if ! __is_container_ready \
				mysql.4 \
				${STARTUP_TIME} \
				"/usr/sbin/mysqld " \
				"[[ -e /var/lib/mysql/ibdata1 ]] \
					&& [[ ! -e /var/lock/subsys/mysqld-bootstrap ]] \
					&& [[ -s /var/run/mysqld/mysqld.pid ]]"
			then
				exit 1
			fi

			describe "User creation"
				it "Creates an unrestricted user."
					# Set MySQL root password
					if docker exec mysql.4 bash command -v mysql_config_editor &> /dev/null
					then
						docker exec -i mysql.4 sshpass mysql_config_editor set --skip-warn --password \
							< ${PWD}/${TEST_DIRECTORY}/fixture/secrets/mysql_root_password
					else
						docker exec mysql.4 bash -c "printf -- '[client]\npassword={{MYSQL_ROOT_PASSWORD}}\n' > /root/.my.cnf"
						docker exec mysql.4 chown 0:0 /root/.my.cnf
						docker exec mysql.4 chmod 0600 /root/.my.cnf
						docker exec -i mysql.4 bash -c "IFS= read -r mysql_root_password; sed -i -e \"s~{{MYSQL_ROOT_PASSWORD}}~\${mysql_root_password}~g\" /root/.my.cnf;" \
							< ${PWD}/${TEST_DIRECTORY}/fixture/secrets/mysql_root_password
					fi

					select_users="$(
						docker exec \
							mysql.4 \
							mysql \
								--batch \
								--skip-column-names \
								--user=root \
								-e "SELECT User, Host from mysql.user ORDER BY User ASC;"
					)"

					assert equal \
						"${select_users}" \
						"$(
							printf -- \
								'%s\t%s\n%s\t%s\n%s\t%s\n%s\t%s' \
								'app2-user' \
								'%' \
								'mysql.session' \
								'localhost' \
								'mysql.sys' \
								'localhost' \
								'root' \
								'localhost'
						)"
				end
			end

			describe "Client to server cross-network connection"
				it "Can successfully connect."
					show_databases="$(
						docker exec \
							-t \
							mysql.5 \
							mysql \
								-h mysql.4 \
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
							mysql.3 \
							mysql \
								-h mysql.4 \
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
				mysql.3 \
			&> /dev/null

			__terminate_container \
				mysql.4 \
			&> /dev/null

			__terminate_container \
				mysql.5 \
			&> /dev/null
		end

		describe "Custom intitialisation"
			it "Runs a named server container."
				docker run \
					--detach \
					--name mysql.6 \
					--network-alias mysql.6 \
					--network ${private_network_1} \
					--env "MYSQL_INIT_LIMIT=30" \
					--env "MYSQL_INIT_SQL=CREATE DATABASE IF NOT EXISTS \`{{MYSQL_USER_DATABASE}}-1\`; GRANT ALL PRIVILEGES ON \`{{MYSQL_USER_DATABASE}}-%\`.* TO '{{MYSQL_USER}}'@'{{MYSQL_USER_HOST}}' IDENTIFIED BY '{{MYSQL_USER_PASSWORD}}'; CREATE TABLE \`{{MYSQL_USER_DATABASE}}-1\`.\`user\` (\`id\` int(10) unsigned NOT NULL AUTO_INCREMENT, \`email\` varchar(255), PRIMARY KEY (\`id\`)) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;" \
					--env "MYSQL_ROOT_PASSWORD=/var/run/secrets/mysql_root_password" \
					--env "MYSQL_SUBNET=172.172.40.0/255.255.255.0" \
					--env "MYSQL_USER=app" \
					--env "MYSQL_USER_PASSWORD=/var/run/secrets/mysql_user_password" \
					--env "MYSQL_USER_DATABASE=appdb" \
					--volume ${data_volume_3}:/var/lib/mysql \
					--volume ${PWD}/${TEST_DIRECTORY}/fixture/secrets:/var/run/secrets:ro \
					jdeathe/centos-ssh-mysql:latest \
				&> /dev/null

				assert equal \
					"${?}" \
					0
			end

			it "Runs a named client container."
				docker run \
					--detach \
					--name mysql.7 \
					--network ${private_network_1} \
					--env "ENABLE_MYSQLD_BOOTSTRAP=false" \
					--env "ENABLE_MYSQLD_WRAPPER=false" \
					jdeathe/centos-ssh-mysql:latest \
				&> /dev/null

				assert equal \
					"${?}" \
					0
			end

			if ! __is_container_ready \
				mysql.6 \
				${STARTUP_TIME} \
				"/usr/sbin/mysqld " \
				"[[ -e /var/lib/mysql/ibdata1 ]] \
					&& [[ ! -e /var/lock/subsys/mysqld-bootstrap ]] \
					&& [[ -s /var/run/mysqld/mysqld.pid ]]"
			then
				exit 1
			fi

			describe "Client to server connection"
				# Set MySQL user password
				if docker exec mysql.7 bash command -v mysql_config_editor &> /dev/null
				then
					docker exec -i mysql.7 sshpass mysql_config_editor set --skip-warn --host=mysql.6 --user=app --password \
						< ${PWD}/${TEST_DIRECTORY}/fixture/secrets/mysql_user_password
				else
					docker exec mysql.7 bash -c "printf -- '[client]\nuser=app\nhost=mysql.6\npassword={{MYSQL_USER_PASSWORD}}\n' > /root/.my.cnf"
					docker exec mysql.7 chown 0:0 /root/.my.cnf
					docker exec mysql.7 chmod 0600 /root/.my.cnf
					docker exec -i mysql.7 bash -c "IFS= read -r mysql_user_password; sed -i -e \"s~{{MYSQL_USER_PASSWORD}}~\${mysql_user_password}~g\" /root/.my.cnf;" \
						< ${PWD}/${TEST_DIRECTORY}/fixture/secrets/mysql_user_password
				fi

				it "Can successfully connect."
					show_tables="$(
						docker exec \
							mysql.7 \
							mysql \
								appdb-1 \
								-N \
								-B \
								-e "SHOW TABLES;"
					)"

					assert equal \
						"${show_tables}" \
						"user"
				end
			end

			__terminate_container \
				mysql.6 \
			&> /dev/null

			__terminate_container \
				mysql.7 \
			&> /dev/null
		end

		describe "Configure autostart"
			__terminate_container \
				mysql.1 \
			&> /dev/null

			docker run \
				--detach \
				--name mysql.1 \
				--env "ENABLE_MYSQLD_BOOTSTRAP=false" \
				jdeathe/centos-ssh-mysql:latest \
			&> /dev/null

			if ! __is_container_ready \
				mysql.1 \
				${STARTUP_TIME} \
				"/usr/sbin/mysqld "
			then
				exit 1
			fi

			it "Can disable mysqld-bootstrap."
				docker logs \
					mysql.1 \
					2> /dev/null \
				| grep -qE 'INFO success: mysqld-bootstrap entered RUNNING state'

				assert equal \
					"${?}" \
					"1"
			end

			__terminate_container \
				mysql.1 \
			&> /dev/null

			docker run \
				--detach \
				--name mysql.1 \
				--env "ENABLE_MYSQLD_WRAPPER=false" \
				jdeathe/centos-ssh-mysql:latest \
			&> /dev/null

			if ! __is_container_ready \
				mysql.1 \
				${STARTUP_TIME} \
				"/usr/bin/python /usr/bin/supervisord " \
				"[[ -e /var/lib/mysql/ibdata1 ]] \
					&& [[ ! -e /var/lock/subsys/mysqld-bootstrap ]]"
			then
				exit 1
			fi

			it "Can disable mysqld-wrapper."
				docker top mysql.1 \
					| grep -qE '/usr/sbin/mysqld '

				assert equal \
					"${?}" \
					"1"
			end

			__terminate_container \
				mysql.1 \
			&> /dev/null
		end
	end

	trap - \
		INT TERM EXIT
}

function test_healthcheck ()
{
	local -r event_lag_seconds=2
	local -r interval_seconds=1
	local -r retries=10
	local events_since_timestamp
	local health_status

	trap "__terminate_container mysql.1 &> /dev/null; \
		__destroy; \
		exit 1" \
		INT TERM EXIT

	describe "Healthcheck"
		describe "Default configuration"
			__terminate_container \
				mysql.1 \
			&> /dev/null

			docker run \
				--detach \
				--name mysql.1 \
				jdeathe/centos-ssh-mysql:latest \
			&> /dev/null

			events_since_timestamp="$(
				date +%s
			)"

			it "Returns a valid status on starting."
				health_status="$(
					docker inspect \
						--format='{{json .State.Health.Status}}' \
						mysql.1
				)"

				assert __shpec_matcher_egrep \
					"${health_status}" \
					"\"(starting|healthy|unhealthy)\""
			end

			it "Returns healthy after startup."
				events_timeout="$(
					awk \
						-v event_lag="${event_lag_seconds}" \
						-v interval="${interval_seconds}" \
						-v startup_time="${STARTUP_TIME}" \
						'BEGIN { print event_lag + startup_time + interval; }'
				)"

				health_status="$(
					test/health_status \
						--container=mysql.1 \
						--since="${events_since_timestamp}" \
						--timeout="${events_timeout}" \
						--monochrome \
					2>&1
				)"

				assert equal \
					"${health_status}" \
					"✓ healthy"
			end

			it "Returns unhealthy on failure."
				# mysqld-wrapper failure
				docker exec -t \
					mysql.1 \
					bash -c "mv \
						/usr/sbin/mysqld \
						/usr/sbin/mysqld2" \
				&& docker exec -t \
					mysql.1 \
					bash -c "if [[ -n \$(pgrep -f '^/usr/sbin/mysqld ') ]]; then \
						kill -9 -\$(ps axo pgid,command | grep -P '/usr/sbin/mysqld --pid-file=/var/run/mysqld/mysqld.pid$' | awk '{ print \$1; }')
					fi"

				events_since_timestamp="$(
					date +%s
				)"

				events_timeout="$(
					awk \
						-v event_lag="${event_lag_seconds}" \
						-v interval="${interval_seconds}" \
						-v retries="${retries}" \
						'BEGIN { print (2 * event_lag) + (interval * retries); }'
				)"

				health_status="$(
					test/health_status \
						--container=mysql.1 \
						--since="$(( ${event_lag_seconds} + ${events_since_timestamp} ))" \
						--timeout="${events_timeout}" \
						--monochrome \
					2>&1
				)"

				assert equal \
					"${health_status}" \
					"✗ unhealthy"
			end

			__terminate_container \
				mysql.1 \
			&> /dev/null
		end
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
	test_healthcheck
	__destroy
end
