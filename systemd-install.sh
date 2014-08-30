#!/usr/bin/env bash

DIR_PATH="$( cd "$( echo "${0%/*}" )"; pwd )"
if [[ $DIR_PATH == */* ]]; then
	cd $DIR_PATH
fi

OPT_SERVICE_NAME_FULL=${SERVICE_NAME_FULL:-mysql.pool-1.1.1@3306.service}
OPT_SERVICE_NAME_SHORT=$(cut -d '@' -f1 <<< "${OPT_SERVICE_NAME_FULL}")

# Force 
systemctl stop ${OPT_SERVICE_NAME_FULL}
docker rm volume-config.${OPT_SERVICE_NAME_SHORT}
docker rm ${OPT_SERVICE_NAME_SHORT}

cp ${OPT_SERVICE_NAME_FULL} /etc/systemd/system/
systemctl daemon-reload
systemctl enable /etc/systemd/system/${OPT_SERVICE_NAME_FULL}
systemctl restart ${OPT_SERVICE_NAME_FULL}

sleep 10

docker logs ${OPT_SERVICE_NAME_SHORT}