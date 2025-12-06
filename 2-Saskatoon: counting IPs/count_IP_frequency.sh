#!/bin/bash
# Script to count the number of appearances of unique IP addresses in a log file
# Usage: ./count_unique_ips.sh <logfile>
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <logfile>"
    exit 1
fi
logfile=$1
# Output format: <IP adress>
awk '{print $1}' "$logfile" | sort | uniq -c | sort -n