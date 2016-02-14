#!/usr/bin/env bash

API_SERVER=${API_SERVER:-"{API_SERVER}"}
KUBECTL=${KUBECTL:-"{KUBECTL}"}

function getRCCount{
    return $KUBECTL -s $API_SERVER --no-headers=true --all-namespaces=true get rc | \
           grep -c ""
}

function killRC{
    #删除RC
    $KUBECTL -s $API_SERVER --no-headers=true --all-namespaces=true get rc | \
    while read line
    do
        #将行转化为数组
        definition=($line)

        #删除RC
        $KUBECTL -s $API_SERVER --namespace=${definition[0]} delete rc ${definition[1]}
    done
}

function killNamespace{
    #删除命名空间
    $KUBECTL -s $API_SERVER --no-headers=true get namespaces | \
    while read line
    do
        #将行转化为数组
        definition=($line)

        #判定是否为默认命名空间
        if [ "${definition[0]}" == "default" ]
        then
            continue
        fi

        #删除命名空间
        $KUBECTL -s $API_SERVER delete namespace ${definition[0]}
    done
}

function killPod{
    #删除POD
    $KUBECTL -s $API_SERVER --no-headers=true --all-namespaces=true get pods | \
    while read line
    do
        #将行转化为数组
        definition=($line)

        #删除POD
        $KUBECTL -s $API_SERVER --namespace=${definition[0]} delete pod ${definition[1]}
    done
}

#删除所有进程
killall python

#循环删除RC
while true
do
#删除RC
$KUBECTL -s $API_SERVER --no-headers=true --all-namespaces=true get rc | \
    while read line
    do
        #将行转化为数组
        definition=($line)

        #删除RC
        $KUBECTL -s $API_SERVER --namespace=${definition[0]} delete rc ${definition[1]}
    done

killPod

killNamespace

#尝试恢复被删除的主机
