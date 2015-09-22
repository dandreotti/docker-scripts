#!/bin/sh
set -ex

BUILD_USER=${BUILD_USER:-build}
BUILD_USER_UID=${BUILD_USER_UID:-1234}
BUILD_USER_HOME=${BUILD_USER_HOME:-/home/${BUILD_USER}}

# Use only GARR and CERN mirrors
echo "include_only=.garr.it,.cern.ch" >> /etc/yum/pluginconf.d/fastestmirror.conf

yum clean all
yum install -y hostname epel-release
yum -y update
yum -y install make createrepo \
  wget rpm-build git tar maven java-1.8.0-openjdk-devel \
  redhat-rpm-config buildsys-macros \
  autoconf automake cmake gcc-c++ libtool

# Setup JAVA 8 as default for maven
echo 'JAVA_HOME=$JVM_ROOT/java-1.8.0' >> /etc/java/java.conf

# Couldn't find a better way to tell alternatives in a *programmatic* way 'always use the latest java 8'
# but this depends on the order of installation of the rpms, so it's really unreliable
echo 1 | alternatives --config java
echo 2 | alternatives --config javac
echo

java -version
javac -version
mvn --version

adduser --uid ${BUILD_USER_UID} ${BUILD_USER}
mkdir ${BUILD_USER_HOME}/.m2
cp /settings.xml ${BUILD_USER_HOME}/.m2
mkdir /m2-repository

chown -R ${BUILD_USER}:${BUILD_USER} ${BUILD_USER_HOME} /m2-repository
yum clean all
