#!/usr/bin/env bash
#日志文件的名称
LOG_NAME="con_5_80"
export LOGNAME
#镜像名称
POD_IMAGE="kubernetes/pause"
export POD_IMAGE
#Pod的CPU资源限制
POD_CPU=${POD_CPU:-5}
export POD_CPU
#Pod的内存资源限制
POD_MEMORY=${POD_MEMORY:-32}
export POD_MEMORY
#RC的Pod复制数
POD_COUNT=${POD_COUNT:-80}
export POD_COUNT
#RC的扩容目标,例如希望扩容到800,则设置为800
POD_UP_COUNT=${POD_UP_COUNT:-160}
export POD_UP_COUNT
#RC的缩容目标,例如希望缩容到400,则设置为400
POD_DOWN_COUNT=${POD_DOWN_COUNT:-40}
export POD_DOWN_COUNT
#RC缩扩容的变化数,例如希望扩缩容200,则设置为200
POD_SCALE_COUNT=${POD_SCALE_COUNT:-40}
export POD_SCALE_COUNT
#随机删除POD的数量
KILL_POD_COUNT=${KILL_POD_COUNT:-1}
export KILL_POD_COUNT
#并发数,同时创建RC的数量
CONCURRENT=${CONCURRENT:-5}
export CONCURRENT

#调用测试套件
source ./suit.sh