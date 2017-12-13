#!/bin/bash

set -xe

CODE_DIR=${CODE_DIR:-/opt/code}
PAP_LIBS=/usr/share/argus/pap/lib

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

TARFILE=${CODE_DIR}/argus-pap/target/argus-pap.tar.gz

## Clean and install new code
if [ -f $TARFILE ]; then
	ls -l ${CODE_DIR}
	find ${PAP_LIBS}/ -iname '*.jar' -exec rm -f '{}' \;
	tar -C / -xvzf ${TARFILE}

	# reconfigure
	run_puppet
fi

# Run
source /etc/sysconfig/argus-pap

LOCALCP=`ls $PAP_LIBS/provided/*.jar | xargs | tr ' ' ':'`
CLASSPATH=$LOCALCP:`ls $PAP_LIBS/*.jar | xargs | tr ' ' ':'`

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

rm -rfv /var/log/argus/pap/pap-standalone.log
ln -s /dev/stdout /var/log/argus/pap/pap-standalone.log

java ${JMX_OPT} ${DEBUG_OPT} ${SSL_DEBUG_OPT} ${JREBEL_OPT} ${PAP_JAVA_OPTS} -DPAP_HOME=${PAP_HOME} \
	-Djava.endorsed.dirs=${PAP_LIBS}/endorsed \
	-cp ${CLASSPATH}:${PAP_HOME}/conf/logging/standalone \
	org.glite.authz.pap.server.standalone.PAPServer \
	--conf-dir ${PAP_HOME}/conf
