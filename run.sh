#!/usr/bin/env bash

# Change working directory
DIR_PATH="$( if [[ $( echo "${0%/*}" ) != $( echo "${0}" ) ]]; then cd "$( echo "${0%/*}" )"; fi; pwd )"
if [[ ${DIR_PATH} == */* ]] && [[ ${DIR_PATH} != $( pwd ) ]]; then
	cd ${DIR_PATH}
fi

source run.conf
source docker-helpers.sh

# Configuration volume
if [[ ${VOLUME_CONFIG_ENABLED} == true ]] && ! have_docker_container_name ${VOLUME_CONFIG_NAME}; then
	echo "Creating configuration volume container."

	if [[ ${VOLUME_CONFIG_NAMED} == true ]]; then
		DOCKER_VOLUME_MAPPING=${VOLUME_CONFIG_NAME}:/etc/services-config
	else
		DOCKER_VOLUME_MAPPING=/etc/services-config
	fi

	(
	set -x
	docker run \
		--name ${VOLUME_CONFIG_NAME} \
		-v ${DOCKER_VOLUME_MAPPING} \
		${DOCKER_IMAGE_REPOSITORY_NAME} \
		/bin/true;
	)

	# Named data volumes require files to be copied into place.
	if [[ ${VOLUME_CONFIG_NAMED} == true ]]; then
		echo "Populating configuration volume."
		(
		set -x
		docker cp \
			./etc/services-config/. \
			${DOCKER_VOLUME_MAPPING};
		)
	fi
fi

# Data volume mapping
if [[ ${VOLUME_DATA_NAMED} == true ]]; then
	DOCKER_DATA_VOLUME_MAPPING=${VOLUME_DATA_NAME}:/var/lib/mysql
else
	DOCKER_DATA_VOLUME_MAPPING=/var/lib/mysql
fi

# Data volume container
if [[ ${VOLUME_DATA_ENABLED} == true ]] && ! have_docker_container_name ${VOLUME_DATA_NAME}; then
	echo "Creating data volume container."

	(
	set -x
	docker run \
		--name ${VOLUME_DATA_NAME} \
		-v ${DOCKER_DATA_VOLUME_MAPPING} \
		${DOCKER_IMAGE_REPOSITORY_NAME} \
		/bin/true;
	)
fi

# Application container
remove_docker_container_name ${DOCKER_NAME}

if [[ ${#} -eq 0 ]]; then
	echo "Running container ${DOCKER_NAME} as a background/daemon process."
	DOCKER_OPERATOR_OPTIONS="-d"
else
	# This is useful for running commands like 'export' or 'env' to check the 
	# environment variables set by the --link docker option.
	# 
	# If you need to pipe to another command, quote the commands. e.g: 
	#   ./run.sh "env | grep MYSQL | sort"
	printf "Running container %s with CMD [/bin/bash -c '%s']\n" "${DOCKER_NAME}" "${*}"
	DOCKER_OPERATOR_OPTIONS="-it --entrypoint /bin/bash --env TERM=${TERM:-xterm}"
fi

if [[ ${SSH_SERVICE_ENABLED} == true ]]; then
	DOCKER_PORT_OPTIONS="-p ${DOCKER_HOST_PORT_MYSQL:-}:3306 -p ${DOCKER_HOST_PORT_SSH:-}:22"
else
	DOCKER_PORT_OPTIONS="-p ${DOCKER_HOST_PORT_MYSQL:-}:3306"
fi

MYSQL_SUBNET=${MYSQL_SUBNET:-$(get_docker_host_mysql_subnet docker0)}

DOCKER_VOLUMES_FROM=
if [[ ${VOLUME_CONFIG_ENABLED} == true ]] && have_docker_container_name ${VOLUME_CONFIG_NAME}; then
	DOCKER_VOLUMES_FROM="--volumes-from ${VOLUME_CONFIG_NAME}"
fi

if [[ ${VOLUME_DATA_ENABLED} == true ]] && have_docker_container_name ${VOLUME_DATA_NAME}; then
	DOCKER_VOLUMES_FROM+="${DOCKER_VOLUMES_FROM:+ }--volumes-from ${VOLUME_DATA_NAME}"
else
	DOCKER_VOLUMES_FROM+="${DOCKER_VOLUMES_FROM:+ }-v ${DOCKER_DATA_VOLUME_MAPPING}"
fi

# In a sub-shell set xtrace - prints the docker command to screen for reference
(
set -x
docker run \
	${DOCKER_OPERATOR_OPTIONS} \
	--name ${DOCKER_NAME} \
	${DOCKER_PORT_OPTIONS} \
	--env "MYSQL_SUBNET=${MYSQL_SUBNET}" \
	${DOCKER_VOLUMES_FROM:-} \
	${DOCKER_IMAGE_REPOSITORY_NAME}${@:+ -c }"${@}"
)

# Use environment variables instead of configuration volume
# (
# set -x
# docker run \
# 	${DOCKER_OPERATOR_OPTIONS} \
# 	--name ${DOCKER_NAME} \
# 	${DOCKER_PORT_OPTIONS} \
# 	--env "MYSQL_SUBNET=localhost" \
# 	--env "MYSQL_USER=app-user" \
# 	--env "MYSQL_USER_PASSWORD=appPassw0rd!" \
# 	--env "MYSQL_USER_DATABASE=app-db" \
# 	${DOCKER_VOLUMES_FROM:-} \
# 	${DOCKER_IMAGE_REPOSITORY_NAME}${@:+ -c }"${@}"
# )

if is_docker_container_name_running ${DOCKER_NAME}; then
	printf -- "\n%s:\n" 'Docker container status'
	show_docker_container_name_status ${DOCKER_NAME}
	printf -- " ${COLOUR_POSITIVE}--->${COLOUR_RESET} %s\n" 'Container running'
elif [[ ${#} -eq 0 ]]; then
	printf -- " ${COLOUR_NEGATIVE}--->${COLOUR_RESET} %s\n" 'ERROR'
	exit 1
fi
