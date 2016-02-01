#!/usr/bin/env bash

API_SERVER=${API_SERVER:-"192.168.0.101:8080"}
NAMESPACE=${NAMESPACE:-"demo"}

LOG_PATH=${LOG_PATH:-"./logs"}
LOG_NAME=${LOG_NAME:-"sample"}

NAMESPACE_TEMPLATE=${NAMESPACE_TEMPLATE:-"./namespace_template.json"}
CREATE_TEMPLATE=${CREATE_TEMPLATE:-"./create_template.json"}
SCALE_DOWN_TEMPLATE=${SCALE_DOWN_TEMPLATE:-"./scale_down_template.json"}
SCALE_UP_TEMPLATE=${SCALE_UP_TEMPLATE:-"./scale_up_template.json"}
CLEAR_TEMPLATE=${CLEAR_TEMPLATE:-"./clear_template.json"}
RC_TEMPLATE=${RC_TEMPLATE:-"./template.json"}
UP_TEMPLATE=${UP_TEMPLATE:-"./up_template.json"}
NODEUP_TEMPLATE=${NODEUP_TEMPLATE:-"./upnode_template.json"}

KILLPOD_TEMPLATE=${KILLNODE_TEMPLATE:-"./killpod_template.json"}
KILLNODE_TEMPLATE=${KILLNODE_TEMPLATE:-"./killnode_template.json"}

KILLPOD=${KILLPOD:-"./killpod.py"}
KILLNODE=${KILLNODE:-"./killnode.py"}
KUBECTL=${KUBECTL:-"./kubectl"}
TEMPLATE=${TEMPLATE:-"./template.sh"}

RC_DEFINITION=${RC_DEFINITION:-"./rc.json"}
RC_NAME=${RC_NAME:-"performance"}

POD_IMAGE=${POD_IMAGE:-"kubernetes/pause"}
POD_CPU=${POD_CPU:-5}
POD_MEMORY=${POD_MEMORY:-32}
POD_COUNT=${POD_COUNT:-1}
POD_UP_COUNT=${POD_UP_COUNT:-2}
POD_DOWN_COUNT=${POD_DOWN_COUNT:-1}
POD_SCALE_COUNT=${POD_SCALE_COUNT:-1}

KILL_POD_COUNT=${KILL_POD_COUNT:-1}

CONCURRENT=${CONCURRENT:-1}

function encode {
    echo "$(echo $1 | sed -e 's/\//\\\//g')"
}

for index in $(seq $CONCURRENT)
do
{
    RC_NAME=$RC_NAME$index
    NAMESPACE=$NAMESPACE$index
    LOG_NAME=$LOG_NAME"_"$index".log"
    RC_DEFINITION="rc_"$index".json"
    NAMESPACE_DEFINITION="namespace_"$index".json"
    CREATE_DEFINITION="create_"$index".json"
    DOWN_DEFINITION="scale_down_"$index".json"
    UP_DEFINITION="scale_up_"$index".json"
    RESTORE_DEFINITION="restore_"$index".json"
    CLEAR_DEFINITION="clear_"$index".json"
    KILLPOD_DEFINITION="killpod_"$index".json"
    KILLNODE_DEFINITION="killnode_"$index".json"
    NODE_DEFINITION="node_"$index".json"
    UPNODE_DEFINITION="upnode_"$index".json"

    echo "======Create namespace $NAMESPACE"
    echo "1:---Generate namespace definition file"
    ./template.sh $NAMESPACE_TEMPLATE $NAMESPACE_DEFINITION '{NAMESPACE}'/$NAMESPACE

    echo "2:---Create namespace"
    $KUBECTL -s $API_SERVER create -f $NAMESPACE_DEFINITION

    echo "======Test creating $POD_COUNT pods"

    echo "3:---Generate replicationController definition file"
    ./template.sh $RC_TEMPLATE $RC_DEFINITION '{RC_NAME}'/$(encode $RC_NAME) '{NAMESPACE}'/$NAMESPACE '{POD_COUNT}'/$POD_COUNT '{POD_IMAGE}'/$(encode $POD_IMAGE) '{POD_CPU}'/$POD_CPU '{POD_MEMORY}'/$POD_MEMORY

    echo "4:---Generate replicationController creation command file"
    ./template.sh $CREATE_TEMPLATE $CREATE_DEFINITION '{CASE_NAME}'/'CREATE' '{KUBECTL}'/$(encode $KUBECTL) '{API_SERVER}'/$API_SERVER '{NAMESPACE}'/$NAMESPACE '{RC_DEFINITION}'/$(encode $RC_DEFINITION) '{POD_COUNT}'/$POD_COUNT '{LOG_PATH}'/$(encode $LOG_PATH) '{LOG_NAME}'/$LOG_NAME

    echo "5:---Create $POD_COUNT pods"
    ./case.py -c $CREATE_DEFINITION

    echo "6:---Generate kill node command file"
    ./template.sh $KILLNODE_TEMPLATE $KILLNODE_DEFINITION '{TEMPLATE}'/$(encode $TEMPLATE) '{NODE_DEFINITION}'/$(encode $NODE_DEFINITION) '{KUBECTL}'/$(encode $KUBECTL) '{API_SERVER}'/$API_SERVER '{NAMESPACE}'/$NAMESPACE
    ./template.sh $NODEUP_TEMPLATE $UPNODE_DEFINITION '{CASE_NAME}'/'KILL_NODE' '{KUBECTL}'/$(encode $KUBECTL) '{STARTER}'/'' '{NODE_DEFINITION}'/$(encode $NODE_DEFINITION) "{START_COMMAND}/$(encode $KILLNODE' -c '$KILLNODE_DEFINITION)" '{API_SERVER}'/$API_SERVER '{NAMESPACE}'/$NAMESPACE '{POD_UP_COUNT}'/1 '{LOG_PATH}'/$(encode $LOG_PATH) '{LOG_NAME}'/$LOG_NAME

    echo "7:---Kill node"
    ./case.py -c $UPNODE_DEFINITION

    echo "8:---Generate kill pod command file"
    ./template.sh $KILLPOD_TEMPLATE $KILLPOD_DEFINITION '{KUBECTL}'/$(encode $KUBECTL) '{API_SERVER}'/$API_SERVER '{NAMESPACE}'/$NAMESPACE '{POD_COUNT}'/$KILL_POD_COUNT
    ./template.sh $UP_TEMPLATE $UP_DEFINITION '{CASE_NAME}'/'KILL_POD' '{STARTER}'/'' "{START_COMMAND}/$(encode $KILLPOD' -c '$KILLPOD_DEFINITION)" '{API_SERVER}'/$API_SERVER '{NAMESPACE}'/$NAMESPACE '{POD_UP_COUNT}'/$KILL_POD_COUNT '{LOG_PATH}'/$(encode $LOG_PATH) '{LOG_NAME}'/$LOG_NAME

    echo "9:---Kill $KILL_POD_COUNT pods"
    ./case.py -c $UP_DEFINITION

    echo "10:---Generate replicationController scale down command file"
    ./template.sh $SCALE_DOWN_TEMPLATE $DOWN_DEFINITION '{CASE_NAME}'/'SCALE_DOWN' '{KUBECTL}'/$(encode $KUBECTL) '{API_SERVER}'/$API_SERVER '{NAMESPACE}'/$NAMESPACE '{RC_NAME}'/$(encode $RC_NAME) '{POD_COUNT}'/$(($POD_COUNT-$POD_DOWN_COUNT)) '{POD_DOWN_COUNT}'/$POD_DOWN_COUNT '{LOG_PATH}'/$(encode $LOG_PATH) '{LOG_NAME}'/$LOG_NAME

    echo "11:---Scale pods from $POD_COUNT to $(($POD_COUNT-$POD_DOWN_COUNT))"
    ./case.py -c $DOWN_DEFINITION

    echo "12:---Generate replicationController restore command file"
    ./template.sh $SCALE_UP_TEMPLATE $RESTORE_DEFINITION '{CASE_NAME}'/'RESTORE' '{KUBECTL}'/$(encode $KUBECTL) '{API_SERVER}'/$API_SERVER '{NAMESPACE}'/$NAMESPACE '{RC_NAME}'/$(encode $RC_NAME) '{POD_COUNT}'/$POD_COUNT '{POD_UP_COUNT}'/$POD_DOWN_COUNT '{LOG_PATH}'/$(encode $LOG_PATH) '{LOG_NAME}'/$LOG_NAME

    echo "13:---Scale pods from $(($POD_COUNT-$POD_DOWN_COUNT)) to $POD_COUNT"
    ./case.py -c $RESTORE_DEFINITION

    echo "14:---Generate replicationController restore command file"
    ./template.sh $SCALE_UP_TEMPLATE $UP_DEFINITION '{CASE_NAME}'/'SCALE_UP' '{KUBECTL}'/$(encode $KUBECTL) '{API_SERVER}'/$API_SERVER '{NAMESPACE}'/$NAMESPACE '{RC_NAME}'/$(encode $RC_NAME) '{POD_COUNT}'/$POD_UP_COUNT '{POD_UP_COUNT}'/$(($POD_UP_COUNT-$POD_COUNT)) '{LOG_PATH}'/$(encode $LOG_PATH) '{LOG_NAME}'/$LOG_NAME

    echo "15:---Scale pods from $POD_COUNT to $POD_UP_COUNT"
    ./case.py -c $UP_DEFINITION

    echo "16:---Generate replicationController restore command file"
    ./template.sh $SCALE_DOWN_TEMPLATE $DOWN_DEFINITION '{CASE_NAME}'/'RESTORE' '{KUBECTL}'/$(encode $KUBECTL) '{API_SERVER}'/$API_SERVER '{NAMESPACE}'/$NAMESPACE '{RC_NAME}'/$(encode $RC_NAME) '{POD_COUNT}'/$POD_COUNT '{POD_DOWN_COUNT}'/$(($POD_UP_COUNT-$POD_COUNT)) '{LOG_PATH}'/$(encode $LOG_PATH) '{LOG_NAME}'/$LOG_NAME

    echo "17:---Scale pods from $POD_UP_COUNT to $POD_COUNT"
    ./case.py -c $DOWN_DEFINITION

    if [ $POD_COUNT -ge $POD_SCALE_COUNT ]; then
        echo "17-1:---Generate replicationController scale down command file"
        ./template.sh $SCALE_DOWN_TEMPLATE $DOWN_DEFINITION '{CASE_NAME}'/'SCALE_FIXED_DOWN' '{KUBECTL}'/$(encode $KUBECTL) '{API_SERVER}'/$API_SERVER '{NAMESPACE}'/$NAMESPACE '{RC_NAME}'/$(encode $RC_NAME) '{POD_COUNT}'/$(($POD_COUNT-$POD_SCALE_COUNT)) '{POD_DOWN_COUNT}'/$POD_SCALE_COUNT '{LOG_PATH}'/$(encode $LOG_PATH) '{LOG_NAME}'/$LOG_NAME

        echo "17-2:---Scale pods from $POD_COUNT to $(($POD_COUNT-$POD_SCALE_COUNT))"
        ./case.py -c $DOWN_DEFINITION

        echo "17-3:---Generate replicationController scale up command file"
        ./template.sh $SCALE_UP_TEMPLATE $UP_DEFINITION '{CASE_NAME}'/'SCALE_FIXED_UP' '{KUBECTL}'/$(encode $KUBECTL) '{API_SERVER}'/$API_SERVER '{NAMESPACE}'/$NAMESPACE '{RC_NAME}'/$(encode $RC_NAME) '{POD_COUNT}'/$POD_COUNT '{POD_UP_COUNT}'/$POD_SCALE_COUNT '{LOG_PATH}'/$(encode $LOG_PATH) '{LOG_NAME}'/$LOG_NAME

        echo "17-4:---Scale pods from $(($POD_COUNT-$POD_SCALE_COUNT)) to $POD_COUNT"
        ./case.py -c $UP_DEFINITION
    fi

    echo "18:---Generate clear command file"
    ./template.sh $CLEAR_TEMPLATE $CLEAR_DEFINITION '{CASE_NAME}'/'CLEAR' '{KUBECTL}'/$(encode $KUBECTL) '{API_SERVER}'/$API_SERVER '{NAMESPACE}'/$NAMESPACE '{RC_NAME}'/$(encode $RC_NAME) '{POD_COUNT}'/$POD_COUNT '{LOG_PATH}'/$(encode $LOG_PATH) '{LOG_NAME}'/$LOG_NAME

    echo "19:---Clear"
    ./case.py -c $CLEAR_DEFINITION

    echo "======Delete namespace $NAMESPACE"
    $KUBECTL -s $API_SERVER delete namespace $NAMESPACE
}&
done
wait