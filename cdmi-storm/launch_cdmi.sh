#!/bin/bash
set -x

MODE="${MODE:-clean}"
PLATFORM="${PLATFORM:-centos6}"
STORM_DEPLOYMENT_TEST_BRANCH=${STORM_DEPLOYMENT_TEST_BRANCH:-master}
REDIS_HOSTNAME="${REDIS_HOSTNAME:-localhost}"
CDMI_CLIENT_ID="${CDMI_CLIENT_ID:-838129a5-84ca-4dc4-bfd8-421ee317aabd}"
if [ -z ${CDMI_CLIENT_SECRET+x} ]; then echo "CDMI_CLIENT_SECRET is unset"; exit 1; fi

# Wait for redis server
MAX_RETRIES=600
attempts=1
CMD="nc -w1 ${REDIS_HOSTNAME} 6379"

echo "Waiting for Redis server ... "
$CMD

while [ $? -eq 1 ] && [ $attempts -le  $MAX_RETRIES ];
do
  sleep 5
  let attempts=attempts+1
  $CMD
done

if [ $attempts -gt $MAX_RETRIES ]; then
    echo "Timeout!"
    exit 1
fi

cd /
git clone https://github.com/italiangrid/storm-deployment-test.git --branch $STORM_DEPLOYMENT_TEST_BRANCH
cd /storm-deployment-test/docker

DEPLOYMENT_SCRIPT="$MODE-cdmi-deployment_$PLATFORM.sh"

chmod +x $DEPLOYMENT_SCRIPT
./$DEPLOYMENT_SCRIPT