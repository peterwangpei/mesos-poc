#!/bin/bash

# Copyright 2015 The Kubernetes Authors All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Notes:
#  - Please install "jq" package before using this driver.
usage() {
	err "Invalid usage. Usage: "
	err "\t$0 init"
	err "\t$0 attach <json params>"
	err "\t$0 detach <mount device>"
	err "\t$0 mount <mount dir> <mount device> <json params>"
	err "\t$0 unmount <mount dir>"
	exit 1
}

err() {
	echo -ne $* 1>&2
}

log() {
	echo -ne $* >&1
}

ismounted() {
	MOUNT=`findmnt -n ${MNTPATH} 2>/dev/null | cut -d' ' -f1`
	if [ "${MOUNT}" == "${MNTPATH}" ]; then
		echo "1"
	else
		echo "0"
	fi
}

attach() {
  log "{\"status\": \"Success\", \"device\":\"/etc/sdb\"}"
	exit 0
}

detach() {
	log "{\"status\": \"Success\"}"
	exit 0
}

domount() {
  MNTPATH=$1
  mkdir -p $MNTPATH
  rm -fr $MNTPATH
  ln -s /mnt/xfs/test $MNTPATHo
	log "{\"status\": \"Success\"}"
	exit 0
}

unmount() {
  MNTPATH=$1
  rm $MNTPATH
  mkdir -p $MNTPATH
	log "{\"status\": \"Success\"}"
	exit 0
}

op=$1

if [ "$op" = "init" ]; then
	log "{\"status\": \"Success\"}"
	exit 0
fi

if [ $# -lt 2 ]; then
	usage
fi

shift

case "$op" in
	attach)
		attach $*
		;;
	detach)
		detach $*
		;;
	mount)
		domount $*
		;;
	unmount)
		unmount $*
		;;
	*)
		usage
esac


exit 1
