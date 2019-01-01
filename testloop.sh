#!/bin/sh

declare -i dockerVolumeWaitLoopCount=0
while [ ! -d "somedirthatwillneverexist" ]; do
    echo "Waiting..."
    sleep 2
    dockerVolumeWaitLoopCount=$dockerVolumeWaitLoopCount+1
    if [ $dockerVolumeWaitLoopCount -ge 10 ]; then
        echo "too many loops. quitting."
        break
    fi
done
