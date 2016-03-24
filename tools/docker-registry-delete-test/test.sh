#!/bin/bash
cd $(dirname $0)/ansible

function get_space_array_from_msg_file () {
  sed -n '/"msg": /p' msg.txt | sed 's/"msg": //g' | sed 's/_/ /g' | sed 's/[[:punct:]]//g'
}

ansible-playbook module/test.yml | tee msg.txt

get_space_array_from_msg_file

rm msg.txt
