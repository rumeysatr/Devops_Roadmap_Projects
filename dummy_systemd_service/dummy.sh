#!/usr/bin/env bash

while true; do
    echo "$(date --iso-8601=seconds) Dummy service is running..." |
        tee -a /var/log/dummy-service.log
    sleep 10
done