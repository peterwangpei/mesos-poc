#!/usr/bin/env bash

#POD的总数
POD_TOTAL=${1:-400}

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

#默认并发数
DEFAULT_CONCURRENT_DEFINITION=(1 2 5 10 20 50 100)

#设置并发数定义
CONCURRENT_DEFINITION=(1 2 5 10 20 50 100)

#重置脚本模板
RESET_TEMPLATE=${RESET_TEMPLATE:-"./reset_template.sh"}

#模板编码
function encode {
    echo "$(echo $1 | sed -e 's/\//\\\//g')"
}

echo "======Create reset script"
./template.sh $RESET_TEMPLATE "reset.sh" '{API_SERVER}'/$API_SERVER '{NAMESPACE}'/$NAMESPACE '{RC_NAME}'/$RC_NAME '{KUBECTL}'/$(encode $KUBECTL) '{CONCURRENT}'/100
chmod a+x ./reset.sh

#设置日志名称
LOG_TEMPLATE_NAME="result_"`date '+%Y%m%d_%H%M%S'`

#循环调用
for index in $(seq ${#CONCURRENT_DEFINITION[*]})
do
    #获得并发数目
    CONCURRENT=${CONCURRENT_DEFINITION[$index-1]}

    #计算任务POD数目
    POD_COUNT=$(($POD_TOTAL/$CONCURRENT))

    #计算比例扩容的POD数目
    POD_UP_COUNT=$(($POD_COUNT*2))

    #计算比例缩容的POD数目
    POD_DOWN_COUNT=$(($POD_COUNT/2))

    #计算固定缩放容POD数目
    POD_SCALE_COUNT=$((200/CONCURRENT))

    #设置日志名称
    LOG_NAME=$LOG_TEMPLATE_NAME"_"$CONCURRENT"_"$POD_COUNT

    #导出环境变量
    export CONCURRENT
    export POD_COUNT
    export POD_UP_COUNT
    export POD_DOWN_COUNT
    export POD_SCALE_COUNT
    export LOG_NAME

    #执行脚本
    ./suit.sh
done