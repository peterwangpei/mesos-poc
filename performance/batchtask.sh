#!/usr/bin/env bash

#输出提示信息
echo "========Arguments List========"
echo "1:Total pod count"
echo "2:Api server address"
echo "3:Container image name"
echo "example ./batchtask.sh 800 192.168.0.101:8080 kubernetes/pause"
echo "=============================="
echo ""

#POD的总数
POD_TOTAL=${1:-400}

#服务器地址
API_SERVER=${2:-"192.168.0.101:8080"}
export API_SERVER

#镜像名称
POD_IMAGE=${3:-"kubernetes/pause"}
export POD_IMAGE

#Pod的CPU资源限制
POD_CPU=${POD_CPU:-5}
export POD_CPU

#Pod的内存资源限制
POD_MEMORY=${POD_MEMORY:-32}
export POD_MEMORY

#Kubectl地址
KUBECTL=${KUBECTL:-"./kubectl"}
export KUBECTL

#设置是否生成套件的清除脚本,默认全局生成,套件不生成
GEN_RESETSCRIPT=false
export GEN_RESETSCRIPT

#设置并发数定义
CONCURRENT_DEFINITION=(${CONCURRENT_DEFINITION:-1 2 5 10 20 50 100})

#重置脚本模板
RESET_TEMPLATE=${RESET_TEMPLATE:-"./reset_template.sh"}

#设置命名空间前缀
NAMESPACE_PREFIX="ns-test"

#设置RC前缀
RC_PREFIX="rc-test"

#模板编码函数
function encode {
    echo "$(echo $1 | sed -e 's/\//\\\//g')"
}

#用于记录当前时间
TIME_STAMP=`date '+%Y%m%d%H%M%S'`

#设置日志名称
LOG_TEMPLATE_NAME="result_"$TIME_STAMP

#循环调用
for index in $(seq ${#CONCURRENT_DEFINITION[*]})
do
    echo "======Generate environment reset script"
    ./template.sh $RESET_TEMPLATE "reset.sh" '{API_SERVER}'/$API_SERVER '{KUBECTL}'/$(encode $KUBECTL)
    chmod a+x ./reset.sh

    #重置环境
    echo "======Reset test environment"
    ./reset.sh

    #获得当前时间
    TIME_STAMP=`date '+%Y%m%d%H%M%S'`

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

    #命名空间名称
    NAMESPACE=$NAMESPACE_PREFIX"-"$TIME_STAMP

    #RC的名称
    RC_NAME=$RC_PREFIX"-"$TIME_STAMP

    #导出环境变量
    export CONCURRENT
    export POD_COUNT
    export POD_UP_COUNT
    export POD_DOWN_COUNT
    export POD_SCALE_COUNT
    export LOG_NAME
    export RC_NAME
    export NAMESPACE

    #执行脚本
    ./suit.sh

    #重置环境
    echo "======Reset test environment"
    ./reset.sh
done