# !/bin/bash

set -e

TAG_WITH_DEST=192.168.33.10/k8smesos/$1

GOO_SRC=gcr.io/google_containers/$1
REPO_DES=k8smesos/$1

if [ -nz $2 ]; then
    docker pull $GOO_SRC
fi

docker tag -f $GOO_SRC $TAG_WITH_DEST
docker push $TAG_WITH_DEST
docker rmi $TAG_WITH_DEST

docker tag $GOO_SRC $REPO_DES
docker push $REPO_DES
docker rmi $REPO_DES
