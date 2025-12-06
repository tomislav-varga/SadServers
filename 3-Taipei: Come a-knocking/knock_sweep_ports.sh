#!/bin/bash
# Script to sweep open ports on a target IP using knock
# Usage: ./knock_sweep_ports.sh <target_ip> <start_port> <end_port>
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <target_ip> <start_port> <end_port>"
    exit 1
fi
target_ip=$1
start_port=$2
end_port=$3
# Loop through ports and knock them
for ((port=start_port; port<=end_port; port++)); do
    knock -v $target_ip $port
done
# Note: Ensure 'knock' utility is installed on your system
