#!/bin/sh
#install ruby, gem, puppet, aws-sdk, thor and some puppetlabs modules
apt-get update
apt-get install ruby -y
apt-get install gem -y
apt-get install puppet -y
gem install aws-adk
gem install thor
puppet module install puppetlabs-mysql
puppet module install puppetlabs-apache
#etc.