# !/bin/bash

set -e

TAG_WITH_DEST=192.168.33.10:5000/$1

if [ -nz $2 ]; then
    docker pull $1
fi

docker tag -f $1 $TAG_WITH_DEST
docker push $TAG_WITH_DEST
docker rmi $TAG_WITH_DEST
