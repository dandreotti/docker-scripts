#!/bin/bash

#install the list of puppet modules after downloading from github
git clone git://github.com/cnaf/ci-puppet-modules.git /ci-puppet-modules

# install all puppet modules required  
# the "--detailed-exitcodes" flag returns explicit exit status:
# exit code '2' means there were changes
# exit code '4' means there were failures during the transaction
# exit code '6' means there were both changes and failures
puppet apply --modulepath=/ci-puppet-modules/modules:/etc/puppet/modules/ --detailed-exitcodes /manifest.pp

# check if errors occurred after puppet apply:
if [[ ( $? -eq 4 ) || ( $? -eq 6 ) ]]; then
  exit 1
fi

# install the MyProxy distribution
yum install -y myproxy myproxy-server myproxy-admin myproxy-doc 

# copy cert and key to proper locations
cp myproxy-server-certificates/myproxy_server.cert.pem /etc/grid-security/myproxy/hostcert.pem
cp myproxy-server-certificates/myproxy_server.key.pem /etc/grid-security/myproxy/hostkey.pem

# chown -R root:root /var/lib/myproxy

chown myproxy:myproxy /etc/grid-security/myproxy/*

chmod 400 /etc/grid-security/myproxy/hostkey.pem 
chmod 644 /etc/grid-security/myproxy/hostcert.pem 

yum install -y fetch-crl

## This is due do a bug in fetch-crl package, that does
## not provide PERL::LWP. Remove the line below when
## this is fixed
yum install -y perl-libwww-perl

# run fetch-crl
fetch-crl

# check if errors occurred after fetch-crl execution
if [ $? != 0 ]; then
  exit 1
fi

# backup deafult configuration files
mv /etc/sysconfig/myproxy-server /etc/sysconfig/myproxy-server.bkp
mv /etc/myproxy-server.config /etc/myproxy-server.config.bkp

# copy myproxy configuration files to proper locations
cp etc_sysconfig_myproxy-server /etc/sysconfig/myproxy-server 
cp etc_myproxy-server.config /etc/myproxy-server.config

# fix init functions
sed -ie 's/pidof -c/\pidof/' /etc/rc.d/init.d/functions
