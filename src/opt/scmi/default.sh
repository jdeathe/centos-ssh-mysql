
# If gawk is available handle incrementing the docker host port for instances
DOCKER_PUBLISH=
if [[ ${DOCKER_PORT_MAP_TCP_3306} != NULL ]]; then
	if grep -qE '^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:)?[0-9]*$' <<< "${DOCKER_PORT_MAP_TCP_3306}" \
		&& grep -qE '^.+\.([0-9]+)\.([0-9]+)$' <<< "${DOCKER_NAME}"; then
		printf -v \
			DOCKER_PUBLISH \
			-- '%s --publish %s%s:3306' \
			"${DOCKER_PUBLISH}" \
			"$(grep -o '^[0-9\.]*:' <<< "${DOCKER_PORT_MAP_TCP_3306}")" \
			"$(( $(grep -o '[0-9]*$' <<< "${DOCKER_PORT_MAP_TCP_3306}") + $(sed 's~\.[0-9]*$~~' <<< "${DOCKER_NAME}" | awk -F. '{ print $NF; }') - 1 ))"
	else
		printf -v \
			DOCKER_PUBLISH \
			-- '%s --publish %s:3306' \
			"${DOCKER_PUBLISH}" \
			"${DOCKER_PORT_MAP_TCP_3306}"
	fi
fi

# Common parameters of create and run targets
DOCKER_CONTAINER_PARAMETERS="--name ${DOCKER_NAME} \
--restart ${DOCKER_RESTART_POLICY} \
--env \"MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}\" \
--env \"MYSQL_ROOT_PASSWORD_HASHED=${MYSQL_ROOT_PASSWORD_HASHED}\" \
--env \"MYSQL_SUBNET=${MYSQL_SUBNET}\" \
--env \"MYSQL_USER=${MYSQL_USER}\" \
--env \"MYSQL_USER_DATABASE=${MYSQL_USER_DATABASE}\" \
--env \"MYSQL_USER_PASSWORD=${MYSQL_USER_PASSWORD}\" \
--env \"MYSQL_USER_PASSWORD_HASHED=${MYSQL_USER_PASSWORD_HASHED}\" \
${DOCKER_PUBLISH}"