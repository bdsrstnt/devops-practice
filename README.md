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
`drupal_status` | --public_ip = public ip of the target server. If not set, then you can choose from a list of EC2 instances. | HTTP GET to the specified host like this: http://{publicIp}/drupal.
`reboot`        | --instance_id = the ID of the instance. If not set, you can choose from a list of EC2 instances. | Reboots the selected EC2 instance.
`start`         | --instance_id = the ID of the instance. If not set, you can choose from a list of EC2 instances. | Starts the selected EC2 instance.
`stop`          | --instance_id = the ID of the instance. If not set, you can choose from a list of EC2 instances. | Stops the selected EC2 instance.
