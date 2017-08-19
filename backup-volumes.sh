#!/bin/bash
# This script allows you to backup all volumes in tar.gz files

BACKUP_PATH="/home/user/Backup/"
#DATE=$(date +"%d-%m-%Y_%H-%M-%S")
DATE=$(date +"%A")

if [ "$1" = 'all' ] || [ -z "$1" ]
then
    VOLUMES=($(docker volume ls -q))
else
    VOLUMES="$1"
fi

for ((i = 0; i < "${#VOLUMES[@]}"; i++))
do
    VOLUME_NAME="${VOLUMES[$i]}"
	
    FILENAME="${VOLUME_NAME}_${DATE}.tar.gz"
    
    echo "Backup docker's volume(s) : "$VOLUME_NAME

    CHECK_RUNNING=$(docker ps --filter "status=running" --filter "volume=$VOLUME_NAME" -q)

    if [ ! -z "$CHECK_RUNNING" ]
    then
        echo "Pause docker container : "$CHECK_RUNNING
        docker pause $CHECK_RUNNING >> /dev/null
    fi

    echo "-Backup Volume from "$VOLUME_NAME" container"
    docker run --rm -v $VOLUME_NAME:/tmp/$VOLUME_NAME -v "$BACKUP_PATH":/backup ubuntu tar -C "/tmp/" -P -czf "/backup/$FILENAME" "$VOLUME_NAME" >> /dev/null
    echo "-Output file name : "$FILENAME
    
    if [ ! -z "$CHECK_RUNNING" ]
    then
        echo "Unpause docker container : "$CHECK_RUNNING
        docker unpause $CHECK_RUNNING >> /dev/null
    fi
    printf "\n"

done
