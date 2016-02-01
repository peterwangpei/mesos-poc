#!/usr/bin/env bash
echo "2 RC 200 Pods"
source ./suit_2_200.sh

echo "5 RC 80 Pods"
source ./suit_5_80.sh

echo "10 RC 40 Pods"
source ./suit_10_40.sh

echo "20 RC 20 Pods"
source ./suit_20_20.sh

echo "50 RC 8 Pods"
source ./suit_50_8.sh

echo "100 RC 4 Pod"
source ./suit_100_4.sh