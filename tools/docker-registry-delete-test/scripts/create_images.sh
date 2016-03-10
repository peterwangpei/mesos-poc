#!/bin/bash
cd $(dirname $0)

IMAGE_COUNT=${1-1}

function remove_existing_random_delete_images () {
  if [ `docker images | grep random/delete-image | wc -l` -gt 0 ]
  then
    docker rmi -f `docker images | grep random/delete-image | awk '{print $3}' | uniq`
  fi
}

function create_file () {
  dd if=/dev/zero of=$1 bs=1024k count=$2
}

function build_images () {
  for i in $(seq 1 $IMAGE_COUNT)
  do
    echo "Start building random/delete-image $i"

    create_random_file

    docker build -t random/delete-image:$i .

    sed -i '1s/.*/FROM random\/delete-image:1/' Dockerfile
  done
}

function create_random_file () {
  echo `uuidgen` > random
}

function remove_temp_files () {
  rm random basefile file1m
}

remove_existing_random_delete_images
create_file "basefile" 5
create_file "file1m" 1
build_images
remove_temp_files
