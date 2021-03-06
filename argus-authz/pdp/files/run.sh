#!/bin/bash

set -xe

CODE_DIR=${CODE_DIR:-/opt/code}

PDP_HOME=/usr/share/argus/pdp
PDP_LIBS=$PDP_HOME/lib

function run_puppet {
	/opt/puppetlabs/bin/puppet apply --modulepath=/opt/ci-puppet-modules/modules:/etc/puppetlabs/code/environments/production/modules /manifest.pp && \
	grep -q 'failure: 0' /opt/puppetlabs/puppet/cache/state/last_run_summary.yaml
}

# Get Puppet modules
if [ ! -d /opt/ci-puppet-modules ]; then
  git clone https://github.com/cnaf/ci-puppet-modules.git /opt/ci-puppet-modules
fi

if [ ! -d /opt/argus-mw-devel ]; then
  git clone https://github.com/argus-authz/argus-mw-devel /opt/argus-mw-devel
  cd /opt/argus-mw-devel/mwdevel_argus
  /opt/puppetlabs/bin/puppet module build
  cd /
fi

# Configure
/opt/puppetlabs/bin/puppet module install /opt/argus-mw-devel/mwdevel_argus/pkg/mwdevel-mwdevel_argus-*.tar.gz
run_puppet

TARFILE=$CODE_DIR/argus-pdp/target/argus-pdp*.tar.gz

## Clean and install new code
if [ -f $TARFILE ]; then
	ls -l $CODE_DIR
	find $PDP_LIBS/ -iname '*.jar' -exec rm -f '{}' \;
	tar -C / -xvzf $CODE_DIR/argus-pdp/target/argus-pdp*.tar.gz

	# reconfigure
	run_puppet
fi

# Run
source /etc/sysconfig/argus-pdp

LOCALCP=/usr/share/java/argus-pdp-pep-common.jar:`ls $PDP_LIBS/provided/*.jar | xargs | tr ' ' ':'`
CLASSPATH=$LOCALCP:`ls $PDP_LIBS/*.jar | xargs | tr ' ' ':'`

JMX_OPT=""
DEBUG_OPT=""
DEBUG_SUSPEND=${DEBUG_SUSPEND:-"n"}
JREBEL_OPT=""
SSL_DEBUG_OPT=${SSL_DEBUG_OPT:-""}

if [ ! -z "$ENABLE_JMX" ] && [ "$ENABLE_JMX" == 'y' ] && [ ! -z "$JMX_PORT" ]; then
	JMX_OPT="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$JMX_PORT -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false"
fi

if [ ! -z "$ENABLE_DEBUG" ] && [ "$ENABLE_DEBUG" == 'y' ] && [ ! -z "$DEBUG_PORT" ]; then
	DEBUG_OPT="-Xdebug -Xrunjdwp:server=y,transport=dt_socket,address=${DEBUG_PORT},suspend=${DEBUG_SUSPEND}"
fi

if [ ! -z "$ENABLE_JREBEL" ] && [ "$ENABLE_JREBEL" == 'y' ]; then
	JREBEL_OPT="-javaagent:/opt/jrebel/jrebel.jar -Drebel.stats=false -Drebel.usage_reporting=false -Drebel.struts2_plugin=true -Drebel.tiles2_plugin=true"
fi

## wait for PAP before start
set +e
start_ts=$(date +%s)
timeout=300
sleeped=0
while true; do
    (echo > /dev/tcp/$PAP_HOST/$PAP_PORT) >/dev/null 2>&1
    result=$?
    if [[ $result -eq 0 ]]; then
        end_ts=$(date +%s)
        echo "$PAP_HOST:$PAP_PORT is available after $((end_ts - start_ts)) seconds"
        break
    fi
    echo "Waiting for PAP..."
    sleep 5

    sleeped=$((sleeped+5))
    if [ $sleeped -ge $timeout  ]; then
    	echo "Timeout!"
    	exit 1
	fi
done
set -e

rm -rfv /var/log/argus/pdp/*

ln -s /dev/stdout /var/log/argus/pdp/access.log
ln -s /dev/stdout /var/log/argus/pdp/audit.log
ln -s /dev/stdout /var/log/argus/pdp/process.log

java -Dorg.glite.authz.pdp.home=${PDP_HOME} \
	-Dorg.glite.authz.pdp.confdir=${PDP_HOME}/conf \
	-Dorg.glite.authz.pdp.logdir=${PDP_HOME}/logs \
	-Djava.endorsed.dirs=${PDP_HOME}/lib/endorsed \
	-classpath ${CLASSPATH} \
	${PDP_JOPTS} ${PDP_START_JOPTS} ${JMX_OPT} ${DEBUG_OPT} ${JREBEL_OPT} ${SSL_DEBUG_OPT}\
	org.glite.authz.pdp.server.PDPDaemon ${PDP_HOME}/conf/pdp.ini
