#!/bin/bash
set -x

VO_HOST=${VO_HOST:-vgrid02.cnaf.infn.it}
VO_PORT=${VO_PORT:-15000}
VO=${VO:-test.vo}
VO_ISSUER=${VO_ISSUER:-/C=IT/O=INFN/OU=Host/L=CNAF/CN=vgrid02.cnaf.infn.it}
TESTSUITE=${TESTSUITE:-git://github.com/italiangrid/voms-testsuite.git}

# check and install the extra repo for VOMS clients if provided by user
if [ -z $VOMSREPO ]; then
  echo "No clients repo provided. Installing default version (EMI3)"
else
  wget "$VOMSREPO" -O /etc/yum.repos.d/vomsclients.repo
  if [ $? != 0 ]; then
    echo "A problem occurred when downloading the provided repo. Installing default version (EMI3)"
  fi
fi

yum install -y voms-clients3
yum install -y myproxy

## Create VOMSES file for VO
rm -rf /etc/vomses/${VO}*
cat << EOF > /etc/vomses/${VO}-${VO_HOST}
"${VO}" "${VO_HOST}" "${VO_PORT}" "${VO_ISSUER}" "${VO}"
EOF

cat << EOF > run-testsuite.sh
#!/bin/bash 
set -ex
git clone $TESTSUITE
pushd ./voms-testsuite
pybot --variable vo1_host:$VO_HOST \
  --variable vo1:$VO \
  --variable vo1_issuer:$VO_ISSUER \
  --pythonpath lib -d reports \
  tests/clients
EOF

# install and execute the VOMS testsuite as user "voms"
exec su - voms sh run-testsuite.sh
