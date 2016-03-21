#!/bin/bash
cd $(dirname $0)

IMAGE_COUNT=${1-1}
IMAGE_SIZE=${2-10}

function remove_existing_random_block_images () {
  if [ `docker images | grep random/block-image | wc -l` -gt 0 ]
  then
    docker rmi -f `docker images | grep random/block-image | awk '{print $3}' | uniq`
  fi
}

function create_big_file () {
  dd if=/dev/urandom of=bigfile bs=977k count=$1
}

function build_images () {
  for i in $(seq 1 $IMAGE_COUNT)
  do
    echo "Start building random/block-image $i"

    create_random_file

    docker build -t random/block-image:`uuidgen` .
  done
}

function create_random_file () {
  echo `uuidgen` > random
}

function remove_temp_files () {
  rm random bigfile
}

remove_existing_random_block_images
create_big_file $IMAGE_SIZE
build_images
remove_temp_files
