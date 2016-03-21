#!/bin/bash
IMAGE_TAGS_TEXT=$(docker images | grep random/block-image | awk '{print $2}')
IMAGE_TAGS=(${IMAGE_TAGS_TEXT//\n/ })
#REGISTRY=$(ps -ef | grep "docker daemon --insecure-registry" | awk '(NR==1){print $11}')
REGISTRY=$1

function tag_images () {
  for tag in "${IMAGE_TAGS[@]}"
  do
    docker tag random/block-image:$tag $REGISTRY/random/block-image:$tag
  done
}

function calculate_push_images_time_spent () {
  START_TIME=$(date +%s%3N)
  for tag in "${IMAGE_TAGS[@]}"
  do
    docker push $REGISTRY/random/block-image:$tag
    END_TIME=$(date +%s%3N)
    MILLISECONDS_SPENT=$(( $END_TIME - $START_TIME ))
    echo $MILLISECONDS_SPENT >> /tmp/milliseconds.csv
    START_TIME=$END_TIME
  done
}

function remove_images () {
  for tag in "${IMAGE_TAGS[@]}"
  do
    docker rmi $REGISTRY/random/block-image:$tag
    docker rmi random/block-image:$tag
  done
}

rm -f /tmp/milliseconds.csv

tag_images
calculate_push_images_time_spent
remove_images
