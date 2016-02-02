#!/usr/bin/env bash

#服务器地址
API_SERVER=${API_SERVER:-"192.168.0.101:8080"}
export API_SERVER

#服务器地址
API_SERVER=${API_SERVER:-"192.168.0.101:8080"}
export API_SERVER

#Pod的CPU资源限制
POD_CPU=${POD_CPU:-5}
export POD_CPU

#Pod的内存资源限制
POD_MEMORY=${POD_MEMORY:-32}
export POD_MEMORY

#镜像名称
POD_IMAGE=${POD_IMAGE:-"kubernetes/pause"}
export POD_IMAGE

#Kubectl地址
KUBECTL=${KUBECTL:-"./kubectl"}
export KUBECTL

#命名空间名称
NAMESPACE=${NAMESPACE:-"performance"}
export NAMESPACE

#RC的名称
RC_NAME=${RC_NAME:-"performance"}
export RC_NAME

#设置是否生成套件的清除脚本,默认全局生成,套件不生成
GEN_RESETSCRIPT=false
export GEN_RESETSCRIPT

function encode {
    echo "$(echo $1 | sed -e 's/\//\\\//g')"
}

echo "======Create reset script"
./template.sh $RESET_TEMPLATE "./reset.sh" '{API_SERVER}'/$API_SERVER '{NAMESPACE}'/$NAMESPACE '{RC_NAME}'/$RC_NAME '{KUBECTL}'/$(encode $KUBECTL) '{CONCURRENT}'/100
chmod a+x ./reset.sh

echo "1 RC 400 Pods"
./suit_1_400.sh

echo "1 RC 800 Pods"
./suit_1_800.sh

echo "2 RC 200 Pods"
./suit_2_200.sh

echo "5 RC 80 Pods"
./suit_5_80.sh

echo "10 RC 40 Pods"
./suit_10_40.sh

echo "20 RC 20 Pods"
./suit_20_20.sh

echo "50 RC 8 Pods"
./suit_50_8.sh

echo "100 RC 4 Pod"
./suit_100_4.sh