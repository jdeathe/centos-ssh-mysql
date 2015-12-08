#!/usr/bin/env bash

DIR_PATH="$( if [ "$( echo "${0%/*}" )" != "$( echo "${0}" )" ] ; then cd "$( echo "${0%/*}" )"; fi; pwd )"
if [[ $DIR_PATH == */* ]] && [[ $DIR_PATH != "$( pwd )" ]] ; then
	cd $DIR_PATH
fi

OPT_SERVICE_NAME_FULL=${SERVICE_NAME_FULL:-mysql.pool-1.1.1@3306.service}
OPT_SERVICE_NAME_SHORT=$(cut -d '@' -f1 <<< "${OPT_SERVICE_NAME_FULL}")

# Add required configuration directories
mkdir -p /etc/services-config/${OPT_SERVICE_NAME_SHORT}/{mysql,supervisor}

if [[ ! -n $(find /etc/services-config/${OPT_SERVICE_NAME_SHORT}/supervisor -maxdepth 1 -type f) ]]; then
	cp -R etc/services-config/supervisor /etc/services-config/${OPT_SERVICE_NAME_SHORT}/
fi

if [[ ! -n $(find /etc/services-config/${OPT_SERVICE_NAME_SHORT}/mysql -maxdepth 1 -type f) ]]; then
	cp -R etc/services-config/mysql /etc/services-config/${OPT_SERVICE_NAME_SHORT}/
fi

# Force 
sudo systemctl stop ${OPT_SERVICE_NAME_FULL}
docker rm volume-config.${OPT_SERVICE_NAME_SHORT}
docker stop ${OPT_SERVICE_NAME_SHORT} && docker rm ${OPT_SERVICE_NAME_SHORT}

sudo cp ${OPT_SERVICE_NAME_FULL} /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable /etc/systemd/system/${OPT_SERVICE_NAME_FULL}

echo "WARNING: This may take a while if pulling large container images for the first time..."
sudo systemctl restart ${OPT_SERVICE_NAME_FULL}

sleep 30

docker logs ${OPT_SERVICE_NAME_SHORT}