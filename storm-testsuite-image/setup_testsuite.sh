#!/bin/bash

TESTSUITE="${TESTSUITE:-git://github.com/italiangrid/storm-testsuite.git}"
STORM_BE_HOST="${STORM_BE_HOST:-docker-storm.cnaf.infn.it}"

echo 'export X509_USER_PROXY="/tmp/x509up_u$(id -u)"'>/etc/profile.d/x509_user_proxy.sh

progress=('/' '-' '\\' '|')

MAX_RETRIES=200

index=0
attempts=1

CMD="nc -z ${STORM_BE_HOST} 8444"

echo "Waiting for StoRM services... "
$CMD

while [ $? -eq 1 ] && [ $attempts -le  $MAX_RETRIES ];
do
  echo -ne ${progress[$index]}\\r
  sleep 5
  let index=(index+1)%4
  let attempts=attempts+1
  $CMD
done

if [ $attempts -gt $MAX_RETRIES ]
  then
    echo "Timeout!"
    exit 1
fi


# install and execute the StoRM testsuite (develop version) as user "tester"
exec su - tester sh -c "git clone $TESTSUITE; cd /home/tester/storm-testsuite; git checkout develop; pybot --pythonpath lib --variable backEndHost:$STORM_BE_HOST --exclude to-be-fixed -d reports tests"

