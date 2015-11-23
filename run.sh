#!/usr/bin/env bash

DIR_PATH="$( if [ "$( echo "${0%/*}" )" != "$( echo "${0}" )" ] ; then cd "$( echo "${0%/*}" )"; fi; pwd )"
if [[ $DIR_PATH == */* ]] && [[ $DIR_PATH != "$( pwd )" ]] ; then
	cd $DIR_PATH
fi

source run.conf

have_docker_container_name ()
{
	local NAME=$1

	if [[ -n $(docker ps -a | awk -v pattern="^${NAME}$" '$NF ~ pattern { print $NF; }') ]]; then
		return 0
	else
		return 1
	fi
}

is_docker_container_name_running ()
{
	local NAME=$1

	if [[ -n $(docker ps | awk -v pattern="^${NAME}$" '$NF ~ pattern { print $NF; }') ]]; then
		return 0
	else
		return 1
	fi
}

remove_docker_container_name ()
{
	local NAME=$1

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
if ! have_docker_container_name ${VOLUME_CONFIG_NAME} ; then
	# For configuration that is specific to the running container
	CONTAINER_MOUNT_PATH_CONFIG=${MOUNT_PATH_CONFIG}/${DOCKER_NAME}

	# For configuration that is shared across a group of containers
	CONTAINER_MOUNT_PATH_CONFIG_SHARED_SSH=${MOUNT_PATH_CONFIG}/ssh.${SERVICE_UNIT_SHARED_GROUP}

	if [ ! -d ${CONTAINER_MOUNT_PATH_CONFIG_SHARED_SSH}/ssh ]; then
			CMD=$(mkdir -p ${CONTAINER_MOUNT_PATH_CONFIG_SHARED_SSH}/ssh)
			$CMD || sudo $CMD
	fi

	# Configuration for SSH is from jdeathe/centos-ssh/etc/services-config/ssh
	#if [[ ! -n $(find ${CONTAINER_MOUNT_PATH_CONFIG_SHARED_SSH}/ssh -maxdepth 1 -type f) ]]; then
	#		CMD=$(cp -R etc/services-config/ssh/ ${CONTAINER_MOUNT_PATH_CONFIG_SHARED_SSH}/ssh/)
	#		$CMD || sudo $CMD
	#fi

	if [ ! -d ${CONTAINER_MOUNT_PATH_CONFIG}/supervisor ]; then
			CMD=$(mkdir -p ${CONTAINER_MOUNT_PATH_CONFIG}/supervisor)
			$CMD || sudo $CMD
	fi

	if [[ ! -n $(find ${CONTAINER_MOUNT_PATH_CONFIG}/supervisor -maxdepth 1 -type f) ]]; then
			CMD=$(cp -R etc/services-config/supervisor ${CONTAINER_MOUNT_PATH_CONFIG}/)
			$CMD || sudo $CMD
	fi

	if [ ! -d ${CONTAINER_MOUNT_PATH_CONFIG}/mysql ]; then
			CMD=$(mkdir -p ${CONTAINER_MOUNT_PATH_CONFIG}/mysql)
			$CMD || sudo $CMD
	fi

	if [[ ! -n $(find ${CONTAINER_MOUNT_PATH_CONFIG}/mysql -maxdepth 1 -type f) ]]; then
			CMD=$(cp -R etc/services-config/mysql ${CONTAINER_MOUNT_PATH_CONFIG}/)
			$CMD || sudo $CMD
	fi

(
set -x
	docker run \
		--name ${VOLUME_CONFIG_NAME} \
		-v ${CONTAINER_MOUNT_PATH_CONFIG_SHARED_SSH}/ssh:/etc/services-config/ssh \
		-v ${CONTAINER_MOUNT_PATH_CONFIG}/supervisor:/etc/services-config/supervisor \
		-v ${CONTAINER_MOUNT_PATH_CONFIG}/mysql:/etc/services-config/mysql \
		busybox:latest \
		/bin/true;
)
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

if [ SSH_SERVICE_ENABLED == "true" ]; then
	DOCKER_PORT_OPTIONS="-p 3306:3306 -p 2400:22"
else
	DOCKER_PORT_OPTIONS="-p 3306:3306"
fi

# In a sub-shell set xtrace - prints the docker command to screen for reference
(
set -x
docker run \
	${DOCKER_OPERATOR_OPTIONS} \
	--name ${DOCKER_NAME} \
	${DOCKER_PORT_OPTIONS} \
	--env MYSQL_SUBNET=${MYSQL_SUBNET:-%} \
	--volumes-from ${VOLUME_CONFIG_NAME} \
	-v ${MOUNT_PATH_DATA}/${SERVICE_UNIT_NAME}/${SERVICE_UNIT_SHARED_GROUP}:/var/lib/mysql \
	${DOCKER_IMAGE_REPOSITORY_NAME} -c "${DOCKER_COMMAND}"
)

if is_docker_container_name_running ${DOCKER_NAME} ; then
	docker ps | awk -v pattern="${DOCKER_NAME}$" '$NF ~ pattern { print $0 ; }'
	echo " ---> Docker container running."
fi
