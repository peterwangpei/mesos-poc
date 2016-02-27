#!/bin/bash

args=("$@")
command="sed $1"

for index in $(seq 3 $#)
do
    command=$command" -e \"s/${args[index-1]}/g\""
done

command=$command" > "${args[1]}

echo $command
eval $command