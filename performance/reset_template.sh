#!/usr/bin/env bash

API_SERVER=${API_SERVER:-"{API_SERVER}"}
KUBECTL=${KUBECTL:-"{KUBECTL}"}

function ClearRC()
{
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

function ClearNamespaces()
{
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

function ClearPods()
{
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

function ClearProcess()
{
    #删除所有Python进程
    while true
    do
        #查询Python进程的数目
        count=`ps -ah | grep -c [p]ython`

        if [ $count -eq  "0" ]
        then
           return
        fi

        #删除Python进程
        killall python

        #休眠一秒
        sleep 1
    done
}

#删除所有Python进程
ClearProcess

#删除所有RC
ClearRC

#删除所有的命名空间
ClearNamespaces

#删除所有的Pods
ClearPods
