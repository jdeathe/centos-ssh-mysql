#!/usr/bin/env bash

# Change working directory
DIR_PATH="$( if [[ $( echo "${0%/*}" ) != $( echo "${0}" ) ]] ; then cd "$( echo "${0%/*}" )"; fi; pwd )"
if [[ ${DIR_PATH} == */* ]] && [[ ${DIR_PATH} != $( pwd ) ]] ; then
	cd ${DIR_PATH}
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
			echo "Stopping container ${NAME}"
			(docker stop ${NAME})
		fi
		echo "Removing container ${NAME}"
		(docker rm ${NAME})
	fi
}

get_docker_host_bridge_ip_addr ()
{
	local IP
	local INTERFACE=${1:-docker0}

	if [[ -n ${DOCKER_HOST} ]]; then
		IP=$(echo ${DOCKER_HOST} | grep -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}")

		if [[ ${INTERFACE} == "docker0" ]] && [[ ${IP} != "127.0.0.1" ]]; then
			# Assume 172.17.0.1/16 for remote docker hosts or VMs
			#IP=172.17.0.1/16
		elif [[ ${INTERFACE} == "eth1" ]] && [[ ${IP} != "127.0.0.1" ]]; then
			# Assume a CIDR of /24 for remote docker hosts or VMs
			IP=${IP}/24
		fi
	elif type "ip" &> /dev/null; then
		IP=$(ip addr show ${INTERFACE} | grep -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}")
	fi

	echo ${IP}
}

get_docker_host_bridge_ip ()
{
	local IP=$(get_docker_host_bridge_ip_addr ${1:-docker0})
	local IP_PARTS=(${IP//\// })

	echo ${IP_PARTS[0]}
}

get_docker_host_bridge_cidr ()
{
	local IP=$(get_docker_host_bridge_ip_addr ${1:-docker0})
	local IP_PARTS=(${IP//\// })

	echo ${IP_PARTS[1]}
}

get_docker_host_mysql_subnet ()
{
	local IP=$(get_docker_host_bridge_ip ${1:-docker0})
	local CIDR=$(get_docker_host_bridge_cidr ${1:-docker0})
	local IP_OCTETS=(${IP//./ })

	# MySQL can only limit connections based on 8, 16, 24 or 32 bits
	case ${CIDR} in
	0)
		# Any IP address/subnet
		echo 0.0.0.0/0.0.0.0
		;;
	1|2|3|4|5|6|7|8)
		# Class A - 10.0.0.0
		echo ${IP_OCTETS[0]}.0.0.0/255.0.0.0
		;;
	9|10|11|12|13|14|15|16)
		# Class B - 10.10.0.0
		echo ${IP_OCTETS[0]}.${IP_OCTETS[1]}.0.0/255.255.0.0
		;;
	17|18|19|20|21|22|23|24)
		# Class C - 10.10.10.0
		echo ${IP_OCTETS[0]}.${IP_OCTETS[1]}.${IP_OCTETS[2]}.0/255.255.255.0
		;;
	*)
		if [[ -z ${IP} ]] || [[ ${IP} == "0.0.0.0" ]]; then
			# Could not determin IP address or CIDR
			echo 0.0.0.0/0.0.0.0
		else
			# Exact match on IP address only
			echo ${IP}/255.255.255.255
		fi
		;;
	esac
}

get_docker_container_ip ()
{
	echo $(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${1:-})
}

get_docker_container_cidr ()
{
	echo $(docker inspect --format '{{ .NetworkSettings.IPPrefixLen }}' ${1:-})
}

get_docker_container_mysql_subnet ()
{
	local IP=$(get_docker_container_ip ${1:-})
	local CIDR=$(get_docker_container_cidr ${1:-})
	local IP_OCTETS=(${IP//./ })

	# MySQL can only limit connections based on 8, 16, 24 or 32 bits
	case ${CIDR} in
	0)
		# Any IP address/subnet
		echo 0.0.0.0/0.0.0.0
		;;
	1|2|3|4|5|6|7|8)
		# Class A - 10.0.0.0
		echo ${IP_OCTETS[0]}.0.0.0/255.0.0.0
		;;
	9|10|11|12|13|14|15|16)
		# Class B - 10.10.0.0
		echo ${IP_OCTETS[0]}.${IP_OCTETS[1]}.0.0/255.255.0.0
		;;
	17|18|19|20|21|22|23|24)
		# Class C - 10.10.10.0
		echo ${IP_OCTETS[0]}.${IP_OCTETS[1]}.${IP_OCTETS[2]}.0/255.255.255.0
		;;
	*)
		# Exact Match IP - 10.10.10.0
		echo ${IP}/255.255.255.255
		;;
	esac
}

# Configuration volume
if ! have_docker_container_name ${VOLUME_CONFIG_NAME} ; then
	# For configuration that is specific to the running container
	CONTAINER_MOUNT_PATH_CONFIG=${MOUNT_PATH_CONFIG}/${DOCKER_NAME}

	# For configuration that is shared across a group of containers
	CONTAINER_MOUNT_PATH_CONFIG_SHARED_SSH=${MOUNT_PATH_CONFIG}/ssh.${SERVICE_UNIT_SHARED_GROUP}

	if [[ ! -d ${CONTAINER_MOUNT_PATH_CONFIG_SHARED_SSH}/ssh ]]; then
		CMD=$(mkdir -p ${CONTAINER_MOUNT_PATH_CONFIG_SHARED_SSH}/ssh)
		$CMD || sudo $CMD
	fi

	if [[ ! -d ${CONTAINER_MOUNT_PATH_CONFIG}/supervisor ]]; then
		CMD=$(mkdir -p ${CONTAINER_MOUNT_PATH_CONFIG}/supervisor)
		$CMD || sudo $CMD
	fi

	if [[ ! -n $(find ${CONTAINER_MOUNT_PATH_CONFIG}/supervisor -maxdepth 1 -type f) ]]; then
		CMD=$(cp -R etc/services-config/supervisor ${CONTAINER_MOUNT_PATH_CONFIG}/)
		$CMD || sudo $CMD
	fi

	if [[ ! -d ${CONTAINER_MOUNT_PATH_CONFIG}/mysql ]]; then
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

if [[ -z ${1+x} ]]; then
	echo "Running container ${NAME} as a background/daemon process."
	DOCKER_OPERATOR_OPTIONS="-d --entrypoint /bin/bash"
	DOCKER_COMMAND="/usr/bin/supervisord --configuration=/etc/supervisord.conf"
else
	# This is useful for running commands like 'export' or 'env' to check the 
	# environment variables set by the --link docker option
	printf "Running container %s with CMD [/bin/bash -c '%s']" "${NAME}" "$@"
	DOCKER_OPERATOR_OPTIONS="--entrypoint /bin/bash"
	DOCKER_COMMAND=${@}
fi

if [[ ${SSH_SERVICE_ENABLED} == "true" ]]; then
	DOCKER_PORT_OPTIONS="-p 3306:3306 -p 2400:22"
else
	DOCKER_PORT_OPTIONS="-p 3306:3306"
fi

MYSQL_SUBNET=${MYSQL_SUBNET:-$(get_docker_host_mysql_subnet docker0)}

# In a sub-shell set xtrace - prints the docker command to screen for reference
(
set -x
docker run \
	${DOCKER_OPERATOR_OPTIONS} \
	--name ${DOCKER_NAME} \
	${DOCKER_PORT_OPTIONS} \
	--env "MYSQL_SUBNET=${MYSQL_SUBNET}" \
	--volumes-from ${VOLUME_CONFIG_NAME} \
	-v ${MOUNT_PATH_DATA}/${SERVICE_UNIT_NAME}/${SERVICE_UNIT_SHARED_GROUP}:/var/lib/mysql \
	${DOCKER_IMAGE_REPOSITORY_NAME} -c "${DOCKER_COMMAND}"
)

if is_docker_container_name_running ${DOCKER_NAME} ; then
	docker ps | awk -v pattern="${DOCKER_NAME}$" '$NF ~ pattern { print $0 ; }'
	echo " ---> Docker container running."
fi
