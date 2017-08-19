#!/bin/bash
# This script allows you to backup all volumes from a container in a tar.gz file
# Origianl idea : https://github.com/quadeare/docker_volumes_backup

BACKUP_PATH="/home/user/Backup/"
#DATE=$(date +"%d-%m-%Y_%H-%M-%S")
DATE=$(date +"%A")
ALL_VOLUME=()

if [ "$1" = 'all' ] || [ -z "$1" ]
then
    CONTAINERS=($(docker ps -a -q))
else
    CONTAINERS="$1"
fi

for ((i = 0; i < "${#CONTAINERS[@]}"; i++))
do
	CONTAINER_ID="${CONTAINERS[$i]}"
	
    FILENAME="${CONTAINER_ID}_${DATE}.tar.gz"
    VOLUMES=$(docker inspect --format='{{range $vol, $path := .Config.Volumes}}{{$vol}} {{end}}' $CONTAINER_ID)
    
    if [ ! -z "$VOLUMES" ]
    then

        echo "Backup docker's volume(s) from : "$CONTAINER_ID
        printf "\n"
    
        CHECK_RUNNING=$(docker ps --filter "status=running" --filter "id=$CONTAINER_ID" -q)

        if [ ! -z "$CHECK_RUNNING" ]
        then
            echo "Pause docker container : "$CONTAINER_ID
            docker pause $CONTAINER_ID >> /dev/null
        fi
 
        echo "Backup datas from "$CONTAINER_ID" container"
        docker run --rm --volumes-from $CONTAINER_ID -v "$BACKUP_PATH":/backup ubuntu tar -P -czf /backup/$FILENAME $VOLUMES >> /dev/null

        if [ ! -z "$CHECK_RUNNING" ]
        then
            echo "Unpause docker container : "$CONTAINER_ID
            docker unpause $CONTAINER_ID >> /dev/null
        fi
    fi	

    echo "Output file name : "$FILENAME

    echo "Done."

done
