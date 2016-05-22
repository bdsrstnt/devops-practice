#!/bin/sh
apt-get update

#install CLI dependencies
gem install aws-sdk
gem install thor

#install release packages for puppet
wget https://apt.puppetlabs.com/puppetlabs-release-pc1-trusty.deb
dpkg -i puppetlabs-release-pc1-trusty.deb
apt-get update -y
apt-get install puppet -y
apt-get install mysql-client -y

#install puppetlabs apache module
puppet module install puppetlabs-apache

#download the drupal-install.pp manifest
wget https://raw.githubusercontent.com/bdsrstnt/devops-practice/master/puppet/drupal-install.pp

#apply the manifest
puppet apply drupal-install.pp
