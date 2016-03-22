#!/bin/bash
cd $(dirname $0)/ansible

function get_time_by_percent () {
  local percent=${1-100}
  local index=`expr $TOTAL_IMAGE_COUNT \* $percent / 100 - 1`

  if [ $index -ge 0 ]
  then
    echo $percent% images pushed in ${SORTED_MILLISECONDS[$index]} milliseconds
  fi
}

function get_milliseconds_array_from_msg_file () {
  local msg=$(sed -n '/\"img_push_ms/p' msg.txt | sed 's/ *\"img_push_ms //g' | sed 's/[[:punct:]]//g')

  local milliseconds=(${msg// / })
  TOTAL_IMAGE_COUNT=${#milliseconds[@]}
  IFS=$'\n' SORTED_MILLISECONDS=($(sort -n <<<"${milliseconds[*]}"))
  unset IFS
}

# ansible-playbook module/docker.yml
ansible-playbook module/test.yml | tee msg.txt

get_milliseconds_array_from_msg_file

echo [${SORTED_MILLISECONDS[@]}]

get_time_by_percent 50
get_time_by_percent 90
get_time_by_percent 95
get_time_by_percent 100

rm msg.txt
