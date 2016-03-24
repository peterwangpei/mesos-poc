#!/bin/bash
TAGS=`docker images | awk '$1 ~ /random\/delete-image/{print $2}'`
TAG_ARR=(${TAGS//\n/ })

for tag in "${TAG_ARR[@]}"
do
  docker tag random/delete-image:$tag $1/random/delete-image:$tag
  docker push $1/random/delete-image:$tag
done
