{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Description": "This template sets up a HA Drupal cluster on Ubuntu 14.04. AMI id: ami-87564feb",
  "Parameters": {
    "KeyName": {
      "Description": "Name of an existing EC2 KeyPair to enable SSH access to the instances",
      "Type": "AWS::EC2::KeyPair::KeyName",
      "ConstraintDescription": "must be the name of an existing EC2 KeyPair."
    },
    "AMIImageId": {
      "Description": "AMI image id",
      "Type": "String",
      "ConstraintDescription": "must be the name of an existing AMI image id."
    },
    "WebServerCapacity": {
      "Default": "2",
      "Description": "The initial number of WebServer instances",
      "Type": "Number",
      "MinValue": "1",
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
  "Conditions": {
    "Is-EC2-VPC": {
      "Fn::Or": [
        {
          "Fn::Equals": [
            {
              "Ref": "AWS::Region"
            },
            "eu-central-1"
          ]
        },
        {
          "Fn::Equals": [
            {
              "Ref": "AWS::Region"
            },
            "cn-north-1"
          ]
        },
        {
          "Fn::Equals": [
            {
              "Ref": "AWS::Region"
            },
            "ap-northeast-2"
          ]
        }
      ]
    },
    "Is-EC2-Classic": {
      "Fn::Not": [
        {
          "Condition": "Is-EC2-VPC"
        }
      ]
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
        "MinSize": "1",
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
    }
  },
  "Outputs": {
    "WebsiteURL": {
      "Description": "URL for newly created LAMP stack",
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
          "x": -20,
          "y": 80
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
          "x": 230,
          "y": 70
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
          "x": -20,
          "y": 230
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
          "x": 280,
          "y": 250
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