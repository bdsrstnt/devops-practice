# Devops-practice
Table of contents

1. [Introduction](#introduction)
2. [Files](#files)
3. [Install Drupal](#install-drupalsh)
4. [Puppet manifest to install Drupal](#drupal-installpp)
5. [AWS CLI to create Drupal cluster](#awsclirb)

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

#### Cluster setup with the CLI

##### Creating the cluster setup
The CLI will use the [drupal_cluster.tpl](https://github.com/bdsrstnt/devops-practice/blob/master/drupal_cluster.tpl) to create the cluster stack.
Parts:
* LoadBalancer
* AutoScalingGroup
* LaunchConfiguration with the previously created AMI
* SecurityGroup for HTTP 80 and SSH 20 access
* RDS MySql database

##### Cooking a base EC2 instance with drupal_recipe.tpl
The [drupal_recipe.tpl](https://github.com/bdsrstnt/devops-practice/blob/master/drupal_recipe.tpl) will create
* an EC2 instance from image **ami-87564feb**

The template will run the [install-drupal.sh](https://github.com/bdsrstnt/devops-practice/blob/master/install-drupal.sh) script to install the **Apache, PHP and Drupal**.
Installation is done by Puppet. The used manifest is [drupal-install.pp](https://github.com/bdsrstnt/devops-practice/blob/master/puppet/drupal-install.pp)

After the installation is done, your instance will have a running Apache with PHP, and Drupal installed on it.

##### Creating AMI from the base instance
After the base instance is up and running, with Drupal installed, the CLI creates a new AMI from this istance. When the AMI is available, the base instance stack is deleted.

##### Adding Drupal to the cluster
The CLI updates the cluster stack with the newly created AMI.

When the process is done, you can access the newly created Drupal cluster via the load balancer.
