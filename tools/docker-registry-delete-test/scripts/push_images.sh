#!/bin/bash
TAG=`docker images | awk '$1 ~ /random\/delete-image/{print $2}'`
docker tag random/delete-image:$TAG $1/random/delete-image:$TAG
docker push $1/random/delete-image:$TAG
