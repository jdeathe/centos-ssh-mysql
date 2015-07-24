#!/usr/bin/env bash

DIR_PATH="$( if [ "$( echo "${0%/*}" )" != "$( echo "${0}" )" ] ; then cd "$( echo "${0%/*}" )"; fi; pwd )"
if [[ $DIR_PATH == */* ]] && [[ $DIR_PATH != "$( pwd )" ]] ; then
	cd $DIR_PATH
fi

source run.conf

have_docker_container_name ()
{
	NAME=$1

	if [[ -n $(docker ps -a | awk -v pattern="^${NAME}$" '$NF ~ pattern { print $NF; }') ]]; then
		return 0
	else
		return 1
	fi
}

is_docker_container_name_running ()
{
	NAME=$1

	if [[ -n $(docker ps | awk -v pattern="^${NAME}$" '$NF ~ pattern { print $NF; }') ]]; then
		return 0
	else
		return 1
	fi
}

remove_docker_container_name ()
{
	NAME=$1

	if have_docker_container_name ${NAME} ; then
		if is_docker_container_name_running ${NAME} ; then
			echo Stopping container ${NAME}...
			(docker stop ${NAME})
		fi
		echo Removing container ${NAME}...
		(docker rm ${NAME})
	fi
}

# Configuration volume
if [ ! "${VOLUME_CONFIG_NAME}" == "$(docker ps -a | grep -v -e \"${VOLUME_CONFIG_NAME}/.*,.*\" | grep -e '[ ]\{1,\}'${VOLUME_CONFIG_NAME} | grep -o ${VOLUME_CONFIG_NAME})" ]; then
	if [ SSH_SERVICE_ENABLED == "true" ]; then
(
set -x
	docker run \
		--name ${VOLUME_CONFIG_NAME} \
		-v ${MOUNT_PATH_CONFIG}/ssh.${SERVICE_UNIT_SHARED_GROUP}:/etc/services-config/ssh \
		-v ${MOUNT_PATH_CONFIG}/${DOCKER_NAME}/supervisor:/etc/services-config/supervisor \
		-v ${MOUNT_PATH_CONFIG}/${DOCKER_NAME}/mysql:/etc/services-config/mysql \
		busybox:latest \
		/bin/true;
)
	else
(
set -x
	docker run \
		--name ${VOLUME_CONFIG_NAME} \
		-v ${MOUNT_PATH_CONFIG}/${DOCKER_NAME}/supervisor:/etc/services-config/supervisor \
		-v ${MOUNT_PATH_CONFIG}/${DOCKER_NAME}/mysql:/etc/services-config/mysql \
		busybox:latest \
		/bin/true;
)
	fi
fi

# Force replace container of same name if found to exist
remove_docker_container_name ${DOCKER_NAME}

if [ -z ${1+x} ]; then
	echo Running container ${NAME} as a background/daemon process...
	DOCKER_OPERATOR_OPTIONS="-d --entrypoint /bin/bash"
	DOCKER_COMMAND="/usr/bin/supervisord --configuration=/etc/supervisord.conf"
else
	# This is usful for running commands like 'export' or 'env' to check the environment variables set by the --link docker option
	echo Running container ${NAME} with command: /bin/bash -c \'"$@"\'...
	DOCKER_OPERATOR_OPTIONS="--entrypoint /bin/bash"
	DOCKER_COMMAND=${@}
fi

# In a sub-shell set xtrace - prints the docker command to screen for reference
if [ SSH_SERVICE_ENABLED == "true" ]; then
(
set -x
docker run \
	${DOCKER_OPERATOR_OPTIONS} \
	--name ${DOCKER_NAME} \
	-p 3306:3306 \
	-p 2400:22 \
	--env MYSQL_SUBNET=${MYSQL_SUBNET:-%} \
	--volumes-from ${VOLUME_CONFIG_NAME} \
	-v ${MOUNT_PATH_DATA}/${SERVICE_UNIT_NAME}/${SERVICE_UNIT_SHARED_GROUP}:/var/lib/mysql \
	${DOCKER_IMAGE_REPOSITORY_NAME} -c "${DOCKER_COMMAND}"
)
else
(
set -x
docker run \
	${DOCKER_OPERATOR_OPTIONS} \
	--name ${DOCKER_NAME} \
	-p 3306:3306 \
	--env MYSQL_SUBNET=${MYSQL_SUBNET:-%} \
	--volumes-from ${VOLUME_CONFIG_NAME} \
	-v ${MOUNT_PATH_DATA}/${SERVICE_UNIT_NAME}/${SERVICE_UNIT_SHARED_GROUP}:/var/lib/mysql \
	${DOCKER_IMAGE_REPOSITORY_NAME} -c "${DOCKER_COMMAND}"
)
fi

if is_docker_container_name_running ${DOCKER_NAME} ; then
	docker ps | awk -v pattern="${DOCKER_NAME}$" '$NF ~ pattern { print $0 ; }'
	echo " ---> Docker container running."
fi
