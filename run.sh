#!/usr/bin/env bash

# Change working directory
DIR_PATH="$( if [[ $( echo "${0%/*}" ) != $( echo "${0}" ) ]]; then cd "$( echo "${0%/*}" )"; fi; pwd )"
if [[ ${DIR_PATH} == */* ]] && [[ ${DIR_PATH} != $( pwd ) ]]; then
	cd ${DIR_PATH}
fi

source run.conf

have_docker_container_name ()
{
	local NAME=$1

	if [[ -z ${NAME} ]]; then
		return 1
	fi

	if [[ -n $(docker ps -a | awk -v pattern="^${NAME}$" '$NF ~ pattern { print $NF; }') ]]; then
		return 0
	fi

	return 1
}

is_docker_container_name_running ()
{
	local NAME=$1

	if [[ -z ${NAME} ]]; then
		return 1
	fi

	if [[ -n $(docker ps | awk -v pattern="^${NAME}$" '$NF ~ pattern { print $NF; }') ]]; then
		return 0
	fi

	return 1
}

remove_docker_container_name ()
{
	local NAME=$1

	if have_docker_container_name ${NAME}; then
		if is_docker_container_name_running ${NAME}; then
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
			# Cannot be sure of the IP for remote docker hosts or VMs
			IP=
		elif  [[ ${INTERFACE} == "eth1" ]] && [[ ${IP} != "127.0.0.1" ]]; then
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
	docker ps | awk -v pattern="${DOCKER_NAME}$" '$NF ~ pattern { print $0; }'
	echo " ---> Docker container running."
fi
