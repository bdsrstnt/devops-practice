# Devops-practice
## Introduction

Install Drupal with Puppet on AWS EC2 Ubuntu instance.
Tested with AMI: ami-87564feb

## Files
### install-drupal.sh

Shell script to install Ruby, Gems, Thor and Puppet.
After installing Puppet, the script will load the drupal-install.pp manifest from this repo, and it will apply the manifest to your EC2 instance.
Once the installation is finished, you can access drupal in your browser on: your_host:your_port/drupal

### drupal-install.pp

Puppet manifest that installs:
* apache
* php
* drupal (latest recommended drupal, with drush)

### awscli.rb

Ruby CLI to handle AWS EC2 instances.
Set the following environment vars:

```sh
export AWS_CLI_ID=your_AWS_client_ID
export AWS_CLI_SECRET=your_AWS_client_secret
export AWS_REGION=your_region
```
Usage
```sh
$ ruby awscli.rb [command] [--options]
```

#### Commands
Command         | Options | Description
----------------|---------|------------
`info`          | -       | Prints instance ID, state and punlic IP of your EC2 instances.
`drupal_status` | --host = public ip or DNS of the target server. If not set, then you can choose from a list of EC2 instances. | HTTP GET to the specified host like this: http://{publicIp}/drupal.
`reboot`        | --instance_id = the ID of the instance. If not set, you can choose from a list of EC2 instances. | Reboots the selected EC2 instance.
`start`         | --instance_id = the ID of the instance. If not set, you can choose from a list of EC2 instances. | Starts the selected EC2 instance.
`stop`          | --instance_id = the ID of the instance. If not set, you can choose from a list of EC2 instances. | Stops the selected EC2 instance.
`autoscale_info` | - | Prints information about your auto scaling groups.
`setup_drupal_ha_cluster` | - | Asks for some data, then sets up a working Drupal cluster in the AWS cloud.
`stack_info` | - | Prints information about your stacks.

### drupal-cluster-ubuntu-1404.template
AWS CloudFormation template.
Creates:
* LoadBalancer
* AutoScalingGroup
* LaunchConfiguration with Ubuntu EC2 instances (AMI id: ami-87564feb) 
* SecurityGroup for HTTP 80 and SSH 22 access, and one for the database access
* DBInstance which is a MySql database

#### About the instances
The launch configuration will create EC2 instances from image **ami-87564feb**.
The config will run the [install-drupal.sh](https://github.com/bdsrstnt/devops-practice/blob/master/install-drupal.sh) script to install the **Apache, PHP and Drupal**.
Installation is done by Puppet. The used manifest is [drupal-install.pp](https://github.com/bdsrstnt/devops-practice/blob/master/puppet/drupal-install.pp)
