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
**autoscale_info**<br>
Prints information about autoscaling groups

**drupal_status [HOST]**<br>
Check drupal status. HOST can be public IP or DNS

**info**<br>
Get info about instances

**start**<br>
Start an instance
```sh
Options:
  [--instance-id=INSTANCE_ID]  # Specifiy which instance to start.
```
**stop**<br>
Stop an instance
```sh
Options:
  [--instance-id=INSTANCE_ID]  # Specifiy which instance to stop.
```

**reboot**<br>
Reboot an instance
```sh
Options:
  [--instance-id=INSTANCE_ID]  # Specifiy which instance to reboot.
```

**stack_info [STACK_NAME]**<br>
Info about the specfied stack

**delete_stack [STACK_NAME]**<br>
Deletes the specfied stack

**setup_drupal_ha_cluster**<br>
Sets up a Drupal cluster with CloudFormation
```sh
Options:
  [--stack-name=STACK_NAME]                        # Name of the stack. Default: myStack
  [--key-name=KEY_NAME]                            # Name of the key-pair, which can be used to connect via SSH.
  [--drupal-admin-password=DRUPAL_ADMIN_PASSWORD]  # Drupal admin password
  [--drupal-site-name=DRUPAL_SITE_NAME]            # Drupal site name. Default: My Drupal Site
  [--db-name=DB_NAME]                              # DB name. Default: myDatabase
  [--db-user=DB_USER]                              # DB admin user name
  [--db-password=DB_PASSWORD]                      # DB admin password
  [--db-allocated-storage=DB_ALLOCATED_STORAGE]    # Db size (Gb). Default: 5
  [--db-instance-class=DB_INSTANCE_CLASS]          # DB instance class. Default: db.t2.micro
  [--web-server-capacity=WEB_SERVER_CAPACITY]      # Webserver capacity, between 1-5. Default: 2
  [--instance-type=INSTANCE_TYPE]                  # EC2 instance type. Default: t2.micro
  [--ssh-location=SSH_LOCATION]                    # Allowed IP's for SSH, in valid IP CIDR range (x.x.x.x/x). Default: 0.0.0.0/0
```

### drupal-cluster-ubuntu-1404.template
AWS CloudFormation template.
Creates:
* LoadBalancer
* AutoScalingGroup
* LaunchConfiguration with Ubuntu EC2 instances (AMI id: ami-87564feb) 
* SecurityGroup for HTTP 80 and SSH 22 access, and one for the database access
* MySql RDS DBInstance

#### About the instances
The launch configuration will create EC2 instances from image **ami-87564feb**.
The config will run the [install-drupal.sh](https://github.com/bdsrstnt/devops-practice/blob/master/install-drupal.sh) script to install the **Apache, PHP and Drupal**.
Installation is done by Puppet. The used manifest is [drupal-install.pp](https://github.com/bdsrstnt/devops-practice/blob/master/puppet/drupal-install.pp)

After the installation is done, your instance will have a running apache with php, and Drupal installed on it.
