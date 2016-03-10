#!/bin/bash
REGISTRY_URL=$1
TAG=`docker images | awk '$1 ~ /^random\/delete-image/{print $2}'`
DIGEST=`curl -i http://$REGISTRY_URL/v2/random/delete-image/manifests/$TAG -H "Content-type: application/json" | grep Docker-Content-Digest | sed -n "s/Docker-Content-Digest: sha256:\(.*\)/\1/p"`
DELETE_URL="http://$REGISTRY_URL/v2/random/delete-image/manifests/sha256:${DIGEST:0:64}"
curl -X DELETE $DELETE_URL
