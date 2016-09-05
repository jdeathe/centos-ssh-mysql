
# If gawk is available handle incrementing the docker host port for instances
if command -v gawk &> /dev/null \
	&& [[ -n $(gawk 'match($0, /^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:)?([0-9]+)$/, matches) { print matches[2]; }' <<< "${DOCKER_PORT_MAP_TCP_3306}") ]]; then
	printf -v \
		DOCKER_PUBLISH \
		-- '--publish %s%s:3306' \
		"$(gawk 'match($0, /^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:)?([0-9]+)$/, matches) { print matches[1]; }' <<< "${DOCKER_PORT_MAP_TCP_3306}")" \
		"$(( $(gawk 'match($0, /^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:)?([0-9]+)$/, matches) { print matches[2]; }' <<< "${DOCKER_PORT_MAP_TCP_3306}") + $(gawk 'match($0, /^.+\.([0-9]+)\.([0-9]+)$/, matches) { print matches[1]; }' <<< "${DOCKER_NAME}") - 1 ))"
else
	printf -v \
		DOCKER_PUBLISH \
		-- '--publish %s:3306' \
		"${DOCKER_PORT_MAP_TCP_3306}"
fi

# Common parameters of create and run targets
DOCKER_CONTAINER_PARAMETERS="--name ${DOCKER_NAME} \
${DOCKER_PUBLISH} \
--restart ${DOCKER_RESTART_POLICY} \
--env \"MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}\" \
--env \"MYSQL_ROOT_PASSWORD_HASHED=${MYSQL_ROOT_PASSWORD_HASHED}\" \
--env \"MYSQL_SUBNET=${MYSQL_SUBNET}\" \
--env \"MYSQL_USER=${MYSQL_USER}\" \
--env \"MYSQL_USER_DATABASE=${MYSQL_USER_DATABASE}\" \
--env \"MYSQL_USER_PASSWORD=${MYSQL_USER_PASSWORD}\" \
--env \"MYSQL_USER_PASSWORD_HASHED=${MYSQL_USER_PASSWORD_HASHED}\""
