#!/bin/sh
#install ruby, gem, puppet, aws-sdk, thor and some puppetlabs modules
apt-get update
apt-add-repository ppa:brightbox/ruby-ng -y
apt-get update
apt-get install ruby -y
apt-get install gem -y
apt-get install mysql-client -y

#install CLI dependencies
gem install aws-sdk
gem install thor
gem install activesupport

#install release packages for puppet
wget https://apt.puppetlabs.com/puppetlabs-release-pc1-trusty.deb
dpkg -i puppetlabs-release-pc1-trusty.deb
apt-get update -y
apt-get install puppet -y

#install puppetlabs apache module
puppet module install puppetlabs-apache

#download the drupal-install.pp manifest from github
wget https://raw.githubusercontent.com/bdsrstnt/devops-practice/master/puppet/drupal-install.pp

#apply the manifest
puppet apply drupal-install.pp