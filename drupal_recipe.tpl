{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Description": "This template sets up a HA Drupal cluster on Ubuntu 14.04. AMI id: ami-87564feb",
  "Parameters": {
    "KeyName": {
      "Description": "Name of an existing EC2 KeyPair to enable SSH access to the instances",
      "Type": "AWS::EC2::KeyPair::KeyName",
      "ConstraintDescription": "must be the name of an existing EC2 KeyPair."
    },
    "DrupalAdminPassword": {
      "NoEcho": "true",
      "Description": "Password for Drupal admin access",
      "Type": "String",
      "MinLength": "8",
      "MaxLength": "41",
      "AllowedPattern": "[a-zA-Z0-9]*",
      "ConstraintDescription": "must contain only alphanumeric characters."
    },
    "DrupalSiteName": {
      "Default": "My Drupal Site",
      "Description": "Name of your Drupal site",
      "Type": "String",
      "MinLength": "1",
      "MaxLength": "64",
      "AllowedPattern": ".*",
      "ConstraintDescription": "must begin with a letter and contain only alphanumeric characters."
    },
    "DBName": {
      "Default": "myDatabase",
      "Description": "MySQL database name",
      "Type": "String",
      "MinLength": "1",
      "MaxLength": "64",
      "AllowedPattern": "[a-zA-Z][a-zA-Z0-9]*",
      "ConstraintDescription": "must begin with a letter and contain only alphanumeric characters."
    },
    "DBUser": {
      "NoEcho": "true",
      "Description": "Username for MySQL database access",
      "Type": "String",
      "MinLength": "1",
      "MaxLength": "16",
      "AllowedPattern": "[a-zA-Z][a-zA-Z0-9]*",
      "ConstraintDescription": "must begin with a letter and contain only alphanumeric characters."
    },
    "DBPassword": {
      "NoEcho": "true",
      "Description": "Password for MySQL database access",
      "Type": "String",
      "MinLength": "8",
      "MaxLength": "41",
      "AllowedPattern": "[a-zA-Z0-9]*",
      "ConstraintDescription": "must contain only alphanumeric characters."
    },
    "DBEndpoint": {
      "Description": "MySQL databse endpoint address",
      "Type": "String"
    },
    "DBPort": {
      "Description": "MySQL databse endpoint port",
      "Type": "Number"
    },
    "InstanceType": {
      "Description": "WebServer EC2 instance type",
      "Type": "String",
      "Default": "t2.micro",
      "AllowedValues": [
        "t1.micro",
        "t2.nano",
        "t2.micro",
        "t2.small",
        "t2.medium",
        "t2.large",
        "m1.small",
        "m1.medium",
        "m1.large",
        "m1.xlarge",
        "m2.xlarge",
        "m2.2xlarge",
        "m2.4xlarge",
        "m3.medium",
        "m3.large",
        "m3.xlarge",
        "m3.2xlarge",
        "m4.large",
        "m4.xlarge",
        "m4.2xlarge",
        "m4.4xlarge",
        "m4.10xlarge",
        "c1.medium",
        "c1.xlarge",
        "c3.large",
        "c3.xlarge",
        "c3.2xlarge",
        "c3.4xlarge",
        "c3.8xlarge",
        "c4.large",
        "c4.xlarge",
        "c4.2xlarge",
        "c4.4xlarge",
        "c4.8xlarge",
        "g2.2xlarge",
        "g2.8xlarge",
        "r3.large",
        "r3.xlarge",
        "r3.2xlarge",
        "r3.4xlarge",
        "r3.8xlarge",
        "i2.xlarge",
        "i2.2xlarge",
        "i2.4xlarge",
        "i2.8xlarge",
        "d2.xlarge",
        "d2.2xlarge",
        "d2.4xlarge",
        "d2.8xlarge",
        "hi1.4xlarge",
        "hs1.8xlarge",
        "cr1.8xlarge",
        "cc2.8xlarge",
        "cg1.4xlarge"
      ],
      "ConstraintDescription": "must be a valid EC2 instance type."
    },
    "SSHLocation": {
      "Description": " The IP address range that can be used to SSH to the EC2 instances",
      "Type": "String",
      "MinLength": "9",
      "MaxLength": "18",
      "Default": "0.0.0.0/0",
      "AllowedPattern": "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})",
      "ConstraintDescription": "must be a valid IP CIDR range of the form x.x.x.x/x."
    }
  },
  "Resources": {
    "BaseInstance": {
      "Type": "AWS::EC2::Instance",
      "Properties": {
        "ImageId": "ami-87564feb",
        "InstanceType": {
          "Ref": "InstanceType"
        },
        "SecurityGroups": [
          {
            "Ref": "WebServerSecurityGroup"
          }
        ],
        "KeyName": {
          "Ref": "KeyName"
        },
        "UserData": {
          "Fn::Base64": {
            "Fn::Join": [
              "",
              [
                "#!/bin/bash -xe\n",
                "#install cfn scripts\n",
                "apt-get -y install python-setuptools\n",
                "easy_install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz\n",
                "#set up facter env vars for puppet\n",
                "export FACTER_DRUPAL_DB_USER=",
                {
                  "Ref": "DBUser"
                },
                "\n",
                "export FACTER_DRUPAL_DB_PASS=",
                {
                  "Ref": "DBPassword"
                },
                "\n",
                "export FACTER_DRUPAL_DB_HOST=",
                {
                  "Ref": "DBEndpoint"
                },
                "\n",
                "export FACTER_DRUPAL_DB_PORT=",
                {
                  "Ref": "DBPort"
                },
                "\n",
                "export FACTER_DRUPAL_DB_NAME=",
                {
                  "Ref": "DBName"
                },
                "\n",
                "export FACTER_DRUPAL_ADMIN_PASS=",
                {
                  "Ref": "DrupalAdminPassword"
                },
                "\n",
                "export FACTER_DRUPAL_SITE_NAME=",
                {
                  "Ref": "DrupalSiteName"
                },
                "\n",
                "#download install-drupal.sh shell script\n",
                "wget https://raw.githubusercontent.com/bdsrstnt/devops-practice/master/install-drupal.sh\n",
                "sh install-drupal.sh\n",
                "#send success message",
                "cfn-init --stack ",
                {
                  "Ref": "AWS::StackName"
                },
                " --region ",
                {
                  "Ref": "AWS::Region"
                },
                "\n",
                "cfn-signal -e $? ",
                "--stack ",
                {
                  "Ref": "AWS::StackName"
                },
                "\n"
              ]
            ]
          }
        }
      },
      "Metadata": {
        "AWS::CloudFormation::Designer": {
          "id": "8bb02f64-068a-4414-9aa1-fc3eab572499"
        }
      }
    },
    "WebServerSecurityGroup": {
      "Type": "AWS::EC2::SecurityGroup",
      "Properties": {
        "GroupDescription": "Enable HTTP access via port 80 locked down to the ELB and SSH access",
        "SecurityGroupIngress": [
          {
            "IpProtocol": "tcp",
            "FromPort": "80",
            "ToPort": "80",
            "CidrIp": {
              "Ref": "SSHLocation"
            }
          },
          {
            "IpProtocol": "tcp",
            "FromPort": "22",
            "ToPort": "22",
            "CidrIp": {
              "Ref": "SSHLocation"
            }
          }
        ]
      },
      "Metadata": {
        "AWS::CloudFormation::Designer": {
          "id": "3b981d07-544c-46e2-bbe7-efb304302694"
        }
      }
    }
  },
  "Outputs": {
    "InstanceIP": {
      "Description": "Public ip of base instance.",
      "Value": {
        "Fn::GetAtt": [
          "BaseInstance",
          "PublicIp"
        ]
      }
    }
  },
  "Metadata": {
    "AWS::CloudFormation::Designer": {
      "3b981d07-544c-46e2-bbe7-efb304302694": {
        "size": {
          "width": 60,
          "height": 60
        },
        "position": {
          "x": 180,
          "y": 90
        },
        "z": 1,
        "embeds": [],
        "isrelatedto": [
          "1a7d1ec6-d68e-4fae-81d9-544a61f36144"
        ]
      },
      "746d6979-c98f-4beb-8e75-a3087a0d851a": {
        "size": {
          "width": 60,
          "height": 60
        },
        "position": {
          "x": 180,
          "y": 210
        },
        "z": 1,
        "embeds": [],
        "isrelatedto": [
          "3b981d07-544c-46e2-bbe7-efb304302694"
        ]
      },
      "9d9c0e54-d927-467e-90d4-cd02caa5c99a": {
        "size": {
          "width": 60,
          "height": 60
        },
        "position": {
          "x": 300,
          "y": 90
        },
        "z": 1,
        "embeds": [],
        "ismemberof": [
          "c93c597d-a049-4c82-a5d7-d86c83b9edd8"
        ],
        "isrelatedto": [
          "746d6979-c98f-4beb-8e75-a3087a0d851a"
        ]
      },
      "727ff702-426a-4e27-82f0-102c93966fa7": {
        "size": {
          "width": 60,
          "height": 60
        },
        "position": {
          "x": 300,
          "y": 210
        },
        "z": 1,
        "embeds": [],
        "ismemberof": [
          "3b981d07-544c-46e2-bbe7-efb304302694"
        ]
      },
      "8bb02f64-068a-4414-9aa1-fc3eab572499": {
        "size": {
          "width": 60,
          "height": 60
        },
        "position": {
          "x": 270,
          "y": 180
        },
        "z": 1,
        "embeds": [],
        "ismemberof": [
          "3b981d07-544c-46e2-bbe7-efb304302694"
        ],
        "isrelatedto": [
          "9d9c0e54-d927-467e-90d4-cd02caa5c99a"
        ]
      }
    }
  }
}