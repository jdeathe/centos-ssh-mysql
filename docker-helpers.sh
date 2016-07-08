#!/usr/bin/env bash

get_docker_host_bridge_ip_addr ()
{
	local IP
	local INTERFACE=${1:-docker0}

	if [[ -n ${DOCKER_HOST} ]]; then
		IP=$(echo ${DOCKER_HOST} | grep -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}")

		if [[ ${INTERFACE} == docker0 ]] && [[ ${IP} != 127.0.0.1 ]]; then
			# Cannot be sure of the IP for remote docker hosts or VMs
			IP=
		elif  [[ ${INTERFACE} == eth1 ]] && [[ ${IP} != 127.0.0.1 ]]; then
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
		if [[ -z ${IP} ]] || [[ ${IP} == 0.0.0.0 ]]; then
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

have_docker_image ()
{
	local NAME=$1

	if [[ -n $(show_docker_image ${NAME}) ]]; then
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
			docker stop ${NAME} &> /dev/null

			if [[ ${?} -ne 0 ]]; then
				return 1
			fi
		fi
		echo "Removing container ${NAME}"
		docker rm ${NAME} &> /dev/null

		if [[ ${?} -ne 0 ]]; then
			return 1
		fi
	fi
}

show_docker_container_name_status ()
{
	local NAME=$1

	if [[ -z ${NAME} ]]; then
		return 1
	fi

	docker ps | \
		awk \
			-v pattern="${NAME}$" \
			'$NF ~ pattern { print $0; }'

}

show_docker_image ()
{
	local NAME=$1
	local NAME_PARTS=(${NAME//:/ })

	# Set 'latest' tag if no tag requested
	if [[ ${#NAME_PARTS[@]} == 1 ]]; then
		NAME_PARTS[1]='latest'
	fi

	docker images | \
		awk \
			-v FS='[ ]+' \
			-v pattern="^${NAME_PARTS[0]}[ ]+${NAME_PARTS[1]} " \
			'$0 ~ pattern { print $0; }'
}
