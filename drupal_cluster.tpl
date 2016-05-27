{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Description": "This template sets up a HA Drupal cluster on Ubuntu 14.04. AMI id: ami-87564feb",
  "Parameters": {
    "KeyName": {
      "Description": "Name of an existing EC2 KeyPair to enable SSH access to the instances",
      "Type": "AWS::EC2::KeyPair::KeyName",
      "ConstraintDescription": "must be the name of an existing EC2 KeyPair."
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
    "DBAllocatedStorage": {
      "Default": "5",
      "Description": "The size of the database (Gb)",
      "Type": "Number",
      "MinValue": "5",
      "MaxValue": "1024",
      "ConstraintDescription": "must be between 5 and 1024Gb."
    },
    "DBInstanceClass": {
      "Description": "The database instance type",
      "Type": "String",
      "Default": "db.t2.micro",
      "AllowedValues": [
        "db.t1.micro",
        "db.m1.small",
        "db.m1.medium",
        "db.m1.large",
        "db.m1.xlarge",
        "db.m2.xlarge",
        "db.m2.2xlarge",
        "db.m2.4xlarge",
        "db.m3.medium",
        "db.m3.large",
        "db.m3.xlarge",
        "db.m3.2xlarge",
        "db.m4.large",
        "db.m4.xlarge",
        "db.m4.2xlarge",
        "db.m4.4xlarge",
        "db.m4.10xlarge",
        "db.r3.large",
        "db.r3.xlarge",
        "db.r3.2xlarge",
        "db.r3.4xlarge",
        "db.r3.8xlarge",
        "db.m2.xlarge",
        "db.m2.2xlarge",
        "db.m2.4xlarge",
        "db.cr1.8xlarge",
        "db.t2.micro",
        "db.t2.small",
        "db.t2.medium",
        "db.t2.large"
      ],
      "ConstraintDescription": "must select a valid database instance type."
    },
    "MultiAZDatabase": {
      "Default": "false",
      "Description": "Create a Multi-AZ MySQL Amazon RDS database instance",
      "Type": "String",
      "AllowedValues": [
        "true",
        "false"
      ],
      "ConstraintDescription": "must be either true or false."
    },
    "AMIImageId": {
      "Description": "AMI image id",
      "Type": "String",
      "Default": "ami-87564feb",
      "ConstraintDescription": "must an existing AMI image id."
    },
    "WebServerCapacity": {
      "Default": "0",
      "Description": "The initial number of WebServer instances",
      "Type": "Number",
      "MinValue": "0",
      "MaxValue": "5",
      "ConstraintDescription": "must be between 1 and 5 EC2 instances."
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
    "ElasticLoadBalancer": {
      "Type": "AWS::ElasticLoadBalancing::LoadBalancer",
      "Properties": {
        "CrossZone": "true",
        "AvailabilityZones": {
          "Fn::GetAZs": ""
        },
        "LBCookieStickinessPolicy": [
          {
            "PolicyName": "CookieBasedPolicy",
            "CookieExpirationPeriod": "30"
          }
        ],
        "Listeners": [
          {
            "LoadBalancerPort": "80",
            "InstancePort": "80",
            "Protocol": "HTTP",
            "PolicyNames": [
              "CookieBasedPolicy"
            ]
          }
        ],
        "HealthCheck": {
          "Target": "HTTP:80/",
          "HealthyThreshold": "2",
          "UnhealthyThreshold": "5",
          "Interval": "10",
          "Timeout": "5"
        }
      },
      "Metadata": {
        "AWS::CloudFormation::Designer": {
          "id": "1a7d1ec6-d68e-4fae-81d9-544a61f36144"
        }
      }
    },
    "WebServerGroup": {
      "Type": "AWS::AutoScaling::AutoScalingGroup",
      "Properties": {
        "AvailabilityZones": {
          "Fn::GetAZs": ""
        },
        "LaunchConfigurationName": {
          "Ref": "LaunchConfig"
        },
        "MinSize": "0",
        "MaxSize": "5",
        "DesiredCapacity": {
          "Ref": "WebServerCapacity"
        },
        "LoadBalancerNames": [
          {
            "Ref": "ElasticLoadBalancer"
          }
        ]
      },
      "CreationPolicy": {
        "ResourceSignal": {
          "Timeout": "PT15M",
          "Count": {
            "Ref": "WebServerCapacity"
          }
        }
      },
      "UpdatePolicy": {
        "AutoScalingRollingUpdate": {
          "MinInstancesInService": "1",
          "MaxBatchSize": "1",
          "PauseTime": "PT15M",
          "WaitOnResourceSignals": "true"
        }
      },
      "Metadata": {
        "AWS::CloudFormation::Designer": {
          "id": "6d61345b-2dbc-427e-b4fb-dd84c3c5d9e5"
        }
      }
    },
    "LaunchConfig": {
      "Type": "AWS::AutoScaling::LaunchConfiguration",
      "Properties": {
        "ImageId": {
          "Ref": "AMIImageId"
        },
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
                "#send success message",
                "cfn-init --stack ",
                {
                  "Ref": "AWS::StackName"
                },
                " --resource LaunchConfig --region ",
                {
                  "Ref": "AWS::Region"
                },
                "\n",
                "cfn-signal -e $? ",
                "--stack ",
                {
                  "Ref": "AWS::StackName"
                },
                " --resource WebServerGroup --region ",
                {
                  "Ref": "AWS::Region"
                },
                "\n"
              ]
            ]
          }
        }
      },
      "Metadata": {
        "AWS::CloudFormation::Designer": {
          "id": "842c5948-b99f-42e9-8b90-805aa3758465"
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
            "SourceSecurityGroupOwnerId": {
              "Fn::GetAtt": [
                "ElasticLoadBalancer",
                "SourceSecurityGroup.OwnerAlias"
              ]
            },
            "SourceSecurityGroupName": {
              "Fn::GetAtt": [
                "ElasticLoadBalancer",
                "SourceSecurityGroup.GroupName"
              ]
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
    },
    "DBEC2SecurityGroup": {
      "Type": "AWS::EC2::SecurityGroup",
      "Properties": {
        "GroupDescription": "Open database for access",
        "SecurityGroupIngress": [
          {
            "IpProtocol": "tcp",
            "FromPort": "3306",
            "ToPort": "3306",
            "CidrIp": "0.0.0.0/0"
          }
        ]
      },
      "Metadata": {
        "AWS::CloudFormation::Designer": {
          "id": "87cef48e-e251-4009-90db-e0759738d160"
        }
      }
    },
    "MySQLDatabase": {
      "Type": "AWS::RDS::DBInstance",
      "Properties": {
        "Engine": "MySQL",
        "DBName": {
          "Ref": "DBName"
        },
        "MultiAZ": {
          "Ref": "MultiAZDatabase"
        },
        "MasterUsername": {
          "Ref": "DBUser"
        },
        "MasterUserPassword": {
          "Ref": "DBPassword"
        },
        "DBInstanceClass": {
          "Ref": "DBInstanceClass"
        },
        "AllocatedStorage": {
          "Ref": "DBAllocatedStorage"
        },
        "VPCSecurityGroups": [
          {
            "Fn::GetAtt": [
              "DBEC2SecurityGroup",
              "GroupId"
            ]
          }
        ]
      },
      "Metadata": {
        "AWS::CloudFormation::Designer": {
          "id": "744aadcd-f28d-419b-80f7-9070486fb968"
        }
      }
    }
  },
  "Outputs": {
    "WebsiteURL": {
      "Description": "URL for newly created Drupal cluster",
      "Value": {
        "Fn::Join": [
          "",
          [
            "http://",
            {
              "Fn::GetAtt": [
                "ElasticLoadBalancer",
                "DNSName"
              ]
            }
          ]
        ]
      }
    },
    "DBUrl": {
      "Description": "URL for newly created Drupal cluster",
      "Value": {
        "Fn::GetAtt": [
          "MySQLDatabase",
          "Endpoint.Address"
        ]
      }
    },
    "DBPort": {
      "Description": "URL for newly created Drupal cluster",
      "Value": {
        "Fn::GetAtt": [
          "MySQLDatabase",
          "Endpoint.Port"
        ]
      }
    }
  },
  "Metadata": {
    "AWS::CloudFormation::Designer": {
      "1a7d1ec6-d68e-4fae-81d9-544a61f36144": {
        "size": {
          "width": 60,
          "height": 60
        },
        "position": {
          "x": -100,
          "y": 90
        },
        "z": 1,
        "embeds": []
      },
      "3b981d07-544c-46e2-bbe7-efb304302694": {
        "size": {
          "width": 60,
          "height": 60
        },
        "position": {
          "x": 20,
          "y": 170
        },
        "z": 1,
        "embeds": [],
        "isrelatedto": [
          "1a7d1ec6-d68e-4fae-81d9-544a61f36144"
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
      "6d61345b-2dbc-427e-b4fb-dd84c3c5d9e5": {
        "size": {
          "width": 60,
          "height": 60
        },
        "position": {
          "x": 20,
          "y": 90
        },
        "z": 1,
        "embeds": [],
        "isconnectedto": [
          "1a7d1ec6-d68e-4fae-81d9-544a61f36144"
        ],
        "isassociatedwith": [
          "727ff702-426a-4e27-82f0-102c93966fa7",
          "842c5948-b99f-42e9-8b90-805aa3758465"
        ]
      },
      "842c5948-b99f-42e9-8b90-805aa3758465": {
        "size": {
          "width": 60,
          "height": 60
        },
        "position": {
          "x": 20,
          "y": 10
        },
        "z": 1,
        "embeds": [],
        "ismemberof": [
          "3b981d07-544c-46e2-bbe7-efb304302694"
        ],
        "isrelatedto": [
          "9d9c0e54-d927-467e-90d4-cd02caa5c99a"
        ]
      },
      "87cef48e-e251-4009-90db-e0759738d160": {
        "size": {
          "width": 60,
          "height": 60
        },
        "position": {
          "x": 220,
          "y": 90
        },
        "z": 1,
        "embeds": []
      },
      "744aadcd-f28d-419b-80f7-9070486fb968": {
        "size": {
          "width": 60,
          "height": 60
        },
        "position": {
          "x": 120,
          "y": 90
        },
        "z": 1,
        "embeds": [],
        "isrelatedto": [
          "87cef48e-e251-4009-90db-e0759738d160"
        ]
      }
    }
  }
}