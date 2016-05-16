#!/bin/bash

set -xe

CODE_DIR=${CODE_DIR:-/opt/code}

PEP_HOME=/usr/share/argus/pepd
PEP_LIBS=$PEP_HOME/lib

# Get Puppet modules
cd /opt
rm -rfv *puppet*

git clone https://github.com/cnaf/ci-puppet-modules.git
git clone https://github.com/marcocaberletti/puppet.git

# Configure
puppet apply --modulepath=/opt/ci-puppet-modules/modules/:/opt/puppet/modules/:/etc/puppet/module/ /manifest.pp

cd /

TARFILE=$CODE_DIR/argus-pep-server/target/argus-pep*.tar.gz

## Clean and install new code
if [ -f $TARFILE ]; then
	ls -l $CODE_DIR
	find $PEP_LIBS/ -iname '*.jar' -exec rm -f '{}' \;
	tar -C / -xvzf $CODE_DIR/argus-pep-server/target/argus-pep*.tar.gz

	# reconfigure
	puppet apply --modulepath=/opt/ci-puppet-modules/modules/:/opt/puppet/modules/:/etc/puppet/module/ /manifest.pp
fi

# Run
source /etc/sysconfig/argus-pepd

LOCALCP=/usr/share/java/argus-pdp-pep-common.jar:/usr/share/java/argus-pep-common.jar:`ls $PEP_LIBS/provided/*.jar | xargs | tr ' ' ':'`
CLASSPATH=$LOCALCP:`ls $PEP_LIBS/*.jar | xargs | tr ' ' ':'`

JMX_OPT=""
DEBUG_OPT=""
JREBEL_OPT=""

if [ ! -z "$ENABLE_JMX" ] && [ "$ENABLE_JMX" == 'y' ] && [ ! -z "$JMX_PORT" ]; then
	JMX_OPT="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$JMX_PORT -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false"
fi

if [ ! -z "$ENABLE_DEBUG" ] && [ "$ENABLE_DEBUG" == 'y' ] && [ ! -z "$DEBUG_PORT" ]; then
	DEBUG_OPT="-Xdebug -Xrunjdwp:server=y,transport=dt_socket,address=$DEBUG_PORT,suspend=n"
fi

if [ ! -z "$ENABLE_JREBEL" ] && [ "$ENABLE_JREBEL" == 'y' ]; then
	JREBEL_OPT="-javaagent:/opt/jrebel/jrebel.jar -Drebel.stats=false -Drebel.usage_reporting=false -Drebel.struts2_plugin=true -Drebel.tiles2_plugin=true"
fi

## wait for PDP before start
set +e
start_ts=$(date +%s)
timeout=300
sleeped=0
while true; do
    (echo > /dev/tcp/$PDP_HOST/$PDP_PORT) >/dev/null 2>&1
    result=$?
    if [[ $result -eq 0 ]]; then
        end_ts=$(date +%s)
        echo "$PDP_HOST:$PDP_PORT is available after $((end_ts - start_ts)) seconds"
        break
    fi
    echo "Waiting for PDP"
    sleep 5

    sleeped=$((sleeped+5))
    if [ $sleeped -ge $timeout  ]; then
    	echo "Timeout!"
    	exit 1
	fi
done
set -e

java -Dorg.glite.authz.pep.home=$PEP_HOME \
	-Dorg.glite.authz.pep.confdir=$PEP_HOME/conf \
	-Dorg.glite.authz.pep.logdir=$PEP_HOME/logs \
	-Djava.endorsed.dirs=$PEP_HOME/lib/endorsed \
	-classpath $CLASSPATH \
	$PEPD_JOPTS $PEPD_START_JOPTS $JMX_OPT $DEBUG_OPT $JREBEL_OPT \
	org.glite.authz.pep.server.PEPDaemon $PEP_HOME/conf/pepd.ini &

sleep 5

tail -f /var/log/argus/pepd/*.log