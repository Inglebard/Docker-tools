#!/bin/bash
# This script allows you to backup all volume and volume container in tar.gz files

command -v jq >/dev/null 2>&1 || { echo >&2 "I require jq but it's not installed.  Aborting."; exit 1; }
command -v basename >/dev/null 2>&1 || { echo >&2 "I require basename but it's not installed.  Aborting."; exit 1; }

BACKUP_PATH="/path/to/Backup/"
#DATE=$(date +"%d-%m-%Y_%H-%M-%S")
DATE=$(date +"%A")

ALLVOLUME=($(docker volume ls -q ))
BACKUPED_VOLUME=()
CONTAINERS=($(docker ps -a -q))

TYPE_CONTAINER='container'
TYPE_VOLUME='volume'
TYPE_BIND='bind'

EXCLUDE_FILE="/path/to/exclude.json"

if [ ! -f "$EXCLUDE_FILE" ]; then
 echo "Exclude file not found!"
 exit 1
fi

if [ ! -d "$BACKUP_PATH" ]; then
 echo "Backup directory not found!"
 exit 1
fi

for ((i = 0; i < "${#CONTAINERS[@]}"; i++))
do
 CONTAINER_ID="${CONTAINERS[$i]}"
 MOUNTS=$(docker inspect --format='{{json .Mounts}}' $CONTAINER_ID)

 #If non-empty should be exluded
 is_container_excluded=$(jq -r --arg TYPE_CONTAINER "$TYPE_CONTAINER" --arg CONTAINER_ID "$CONTAINER_ID" '.[] | select((.Value == $CONTAINER_ID) and (.Type == $TYPE_CONTAINER))' "$EXCLUDE_FILE")

 if [ ! -z "$MOUNTS" ] && [ -z "$is_container_excluded" ]
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

     is_volume_excluded=$(jq -r --arg TYPE_VOLUME "$TYPE_VOLUME" --arg volume_name "$volume_name" '.[] | select((.Value == $volume_name) and (.Type == $TYPE_VOLUME))' "$EXCLUDE_FILE")

     if [ -z "$is_volume_excluded" ]
     then
      FILENAME="${CONTAINER_ID}_${volume_name}_${DATE}.tar.gz"
      BACKUPED_VOLUME+=("$volume_name")

      echo "-Backup $volume_name from $CONTAINER_ID container"
      docker run --rm -v $volume_name:/tmp/$volume_name -v "$BACKUP_PATH":/backup ubuntu tar -C "/tmp/" -P -czf "/backup/$FILENAME" "$volume_name" >> /dev/null
      echo "-Output file name : "$FILENAME
      echo "-----------------------------"
     else
      echo "Volume $volume_name excluded"
      echo "-----------------------------"

     fi


   elif [ ! -z "$type" ] && [ "$type" = 'bind' ]
    then
     source=$(echo $MOUNTS | jq -r ".[$j].Source")
     bind_name=$(basename "$source")

     is_bind_excluded=$(jq -r --arg TYPE_BIND "$TYPE_BIND" --arg source "$source" '.[] | select((.Value == $source) and (.Type == $TYPE_BIND))' "$EXCLUDE_FILE")

     if [ -z "$is_bind_excluded" ]
     then
      FILENAME="${CONTAINER_ID}_${bind_name}_${DATE}.tar.gz"

      echo "-Backup \"$source\" from $CONTAINER_ID container"
      docker run --rm -v $source:/tmp/$bind_name -v "$BACKUP_PATH":/backup ubuntu tar -C "/tmp/" -P -czf "/backup/$FILENAME" "$bind_name" >> /dev/null
      echo "-Output file name : "$FILENAME
      echo "-----------------------------"
     else
      echo "Bind $source excluded"
      echo "-----------------------------"

     fi
    fi
   done
  fi

  if [ ! -z "$CHECK_RUNNING" ]
  then
   echo "Unpause docker container : "$CONTAINER_ID
   docker unpause $CONTAINER_ID >> /dev/null
  fi
  printf "\n"
 else
  echo "No mount or container $CONTAINER_ID excluded"
  echo "-----------------------------"
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
   break
  fi
 done

 is_volume_excluded=$(jq -r --arg TYPE_VOLUME "$TYPE_VOLUME" --arg volume_name "${i}" '.[] | select((.Value == $volume_name) and (.Type == $TYPE_VOLUME))' "$EXCLUDE_FILE")

 is_container_excluded=false;
 container_attached=$(docker ps -f "volume=${i}" -q)
 for ((k = 0; k < "${#container_attached[@]}"; k++))
 do
  container_attached_id="${container_attached[$k]}"
  is_container_attached_id_excluded=$(jq -r --arg TYPE_CONTAINER "$TYPE_CONTAINER" --arg container_id "${container_attached_id}" '.[] | select((.Value == $container_id) and (.Type == $TYPE_CONTAINER))' "$EXCLUDE_FILE")
  if [ ! -z "$is_container_attached_id_excluded" ]
  then
   is_container_excluded=true
   break
  fi
 done


 if [ "$match" = "false" ] && [ -z "$is_volume_excluded" ] && [ "$is_container_excluded" = "false" ]
 then
  FILENAME="nocontainer_${i}_${DATE}.tar.gz"
  echo "Backup $i"
  docker run --rm -v $i:/tmp/$i -v "$BACKUP_PATH":/backup ubuntu tar -C "/tmp/" -P -czf "/backup/$FILENAME" "$i" >> /dev/null
  echo "Output file name : "$FILENAME
  printf "\n"
 fi
 if [ ! -z "$is_volume_excluded" ]
 then
  echo "Volume ${i} excluded"
  printf "\n"
 fi
 if [ "$is_container_excluded" = true ]
 then
  echo "Container of volume ${i} excluded"
  printf "\n"
 fi


done
