#!/bin/bash
# This script allows you to backup all volume and volume container in tar.gz files

command -v jq >/dev/null 2>&1 || { echo >&2 "I require jq but it's not installed.  Aborting."; exit 1; }
command -v basename >/dev/null 2>&1 || { echo >&2 "I require basename but it's not installed.  Aborting."; exit 1; }

BACKUP_PATH="/home/user/Backup/"
#DATE=$(date +"%d-%m-%Y_%H-%M-%S")
DATE=$(date +"%A")

ALLVOLUME=($(docker volume ls -q ))
BACKUPED_VOLUME=()
CONTAINERS=($(docker ps -a -q))

for ((i = 0; i < "${#CONTAINERS[@]}"; i++))
do
  CONTAINER_ID="${CONTAINERS[$i]}"
  MOUNTS=$(docker inspect --format='{{json .Mounts}}' $CONTAINER_ID)

  if [ ! -z "$MOUNTS" ]
  then
    echo "Backup docker's volume(s) from : "$CONTAINER_ID

    CHECK_RUNNING=$(docker ps --filter "status=running" --filter "id=$CONTAINER_ID" -q)

    if [ ! -z "$CHECK_RUNNING" ]
    then
      echo "Pause docker container : "$CONTAINER_ID
      docker pause $CONTAINER_ID >> /dev/null
    fi


    mounts_len=$(echo $MOUNTS | jq -r '. | length')

    if [ ! -z "$mounts_len" ]
    then
      for ((j = 0; j < "$mounts_len"; j++))
      do
        type=$(echo $MOUNTS | jq -r ".[$j].Type")
        if [ ! -z "$type" ] && [ "$type" = 'volume' ]
        then
          volume_name=$(echo $MOUNTS | jq -r ".[$j].Name")
          FILENAME="${CONTAINER_ID}_${volume_name}_${DATE}.tar.gz"
          BACKUPED_VOLUME+=("$volume_name")

          echo "-Backup $volume_name from $CONTAINER_ID container"
          docker run --rm -v $volume_name:/tmp/$volume_name -v "$BACKUP_PATH":/backup ubuntu tar -C "/tmp/" -P -czf "/backup/$FILENAME" "$volume_name" >> /dev/null
          echo "-Output file name : "$FILENAME
          echo "-----------------------------"

      elif [ ! -z "$type" ] && [ "$type" = 'bind' ]
        then
          source=$(echo $MOUNTS | jq -r ".[$j].Source")
          bind_name=$(basename "$source")

          FILENAME="${CONTAINER_ID}_${bind_name}_${DATE}.tar.gz"

          echo "-Backup \"$source\" from $CONTAINER_ID container"
          docker run --rm -v $source:/tmp/$bind_name -v "$BACKUP_PATH":/backup ubuntu tar -C "/tmp/" -P -czf "/backup/$FILENAME" "$bind_name" >> /dev/null
          echo "-Output file name : "$FILENAME
          echo "-----------------------------"
        fi
      done
    fi

    if [ ! -z "$CHECK_RUNNING" ]
    then
      echo "Unpause docker container : "$CONTAINER_ID
      docker unpause $CONTAINER_ID >> /dev/null
    fi
    printf "\n"
  fi
done

for i in "${ALLVOLUME[@]}"
do
  match=false
  for j in "${BACKUPED_VOLUME[@]}"
  do
    if [ "$i" = "$j" ]
    then
      match=true
    fi
  done

  if [ "$match" = "false" ]
  then
    FILENAME="nocontainer_${i}_${DATE}.tar.gz"
    echo "Backup $i"
    docker run --rm -v $i:/tmp/$i -v "$BACKUP_PATH":/backup ubuntu tar -C "/tmp/" -P -czf "/backup/$FILENAME" "$i" >> /dev/null
    echo "Output file name : "$FILENAME
    printf "\n"
  fi


done
