#!/usr/bin/ruby
require 'aws-sdk'
require 'thor'
require 'net/http'
require 'securerandom'

AWS_CLI_ID = 'AWS_CLI_ID'.freeze
AWS_CLI_SECRET = 'AWS_CLI_SECRET'.freeze
AWS_REGION = 'AWS_REGION'.freeze

# check aws access data
if !ENV.key?(AWS_CLI_ID) || !ENV.key?(AWS_CLI_SECRET) || !ENV.key?(AWS_REGION)
  raise "Set ENV entries: #{AWS_CLI_ID} , #{AWS_CLI_SECRET}, #{AWS_REGION}"
end

Aws.config.update(access_key_id: ENV[AWS_CLI_ID],
                  secret_access_key: ENV[AWS_CLI_SECRET],
                  region: ENV[AWS_REGION])

# Class to get info and interact with AWS EC2 instances and auto scaling groups.
class AwsCli < Thor
  TYPE_INSTANCE_ID = 'Type instance ID:'.freeze
  TYPE_PUBLIC_IP = 'Type public IP:'.freeze

  desc 'drupal_status', 'check drupal status'
  method_option :host, desc: 'Specifiy public IP or DNS of host where Drupal is running.'
  def drupal_status
    host = get_host(options)
    uri = URI("http://#{host}/drupal/")
    res = Net::HTTP.get_response(uri)
    puts res.body
    puts res.code
  end

  desc 'info', 'get info about instances'
  def info
    ec2 = Aws::EC2::Resource.new

    ec2.instances.each do |i|
      puts "Instance ID: #{i.id}"
      puts "State: #{i.state.name}"
      puts "Public IP: #{i.public_ip_address}"
      puts ''
    end
  end

  desc 'reboot', 'reboots an instance'
  method_option :instance_id, desc: 'Specifiy which instance to start.'
  def reboot
    ec2 = Aws::EC2::Resource.new

    instance_id = get_instance_id(options)

    i = ec2.instance(instance_id)

    if i.exists?
      case i.state.code
        when 48 # terminated
          puts "#{instance_id} is terminated, so you cannot reboot it"
        else
          i.reboot
      end
    end
  end

  desc 'start', 'start an instance'
  method_option :instance_id, desc: 'Specifiy which instance to start.'
  def start
    ec2 = Aws::EC2::Resource.new

    instance_id = get_instance_id(options)

    i = ec2.instance(instance_id)

    if i.exists?
      case i.state.code
        when 0  # pending
          puts "#{instance_id} is pending, so it will be running in a bit"
        when 16  # started
          puts "#{instance_id} is already started"
        when 48  # terminated
          puts "#{instance_id} is terminated, so you cannot start it"
        else
          i.start
      end
    end
  end

  desc 'stop', 'stop an instance'
  method_option :instance_id, desc: 'Specifiy which instance to stop.'
  def stop
    ec2 = Aws::EC2::Resource.new

    instance_id = get_instance_id(options)

    i = ec2.instance(instance_id)

    if i.exists?
      case i.state.code
        when 48  # terminated
          puts "#{instance_id} is terminated, so you cannot stop it"
        when 64  # stopping
          puts "#{instance_id} is stopping, so it will be stopped in a bit"
        when 89  # stopped
          puts "#{instance_id} is already stopped"
        else
          i.stop
          puts "#{instance_id} stop process started"
      end
    end
  end

  desc 'autoscale_info', 'prints information about autoscaling groups.'
  def autoscale_info
    resource = Aws::AutoScaling::Resource.new
    client = Aws::ElasticLoadBalancing::Client.new
    resource.groups.each do |autoscalinggroup|
      puts "Group name: #{autoscalinggroup.auto_scaling_group_name}"
      puts "Launch config name: #{autoscalinggroup.launch_configuration_name}"
      puts "Min size: #{autoscalinggroup.min_size}"
      puts "Max size: #{autoscalinggroup.max_size}"
      puts "Desired size: #{autoscalinggroup.desired_capacity}"
      puts 'Loadbalancers: '
      lbresp = client.describe_load_balancers({load_balancer_names: autoscalinggroup.load_balancer_names})
      lbresp.load_balancer_descriptions.each do |lb|
        puts "Name: #{lb.load_balancer_name}"
        puts "Public DNS: #{lb.dns_name}"
      end
      puts "Attached instances - #{autoscalinggroup.instances.size}: "
      autoscalinggroup.instances.each do |instance|
        puts "  ID: #{instance.id}"
      end
      puts '---'
    end
  end

  desc 'setup_drupal_ha_cluster', 'sets up a drupal cluster with CloudFormation'
  def setup_drupal_ha_cluster
    stack_name = get_user_input('Stack name', 'myStack')
    ssh_key = get_template_parameter('SSH acces key name', 'default', 'KeyName')
    drupal_admin_pass = get_template_parameter('Drupal admin password', 'admin123', 'DrupalAdminPassword')
    drupal_site_name = get_template_parameter('Drupal site name', 'My Drupal Site', 'DrupalSiteName')
    db_name = get_template_parameter('Database name', 'drupaldb', 'DBName')
    db_admin = get_template_parameter('Database master user name', 'admin', 'DBUser')
    db_admin_pass = get_template_parameter('Database master user password', 'admin123', 'DBPassword')
    db_allocated_strorage = get_template_parameter('The size of the database (Gb)', '5', 'DBAllocatedStorage')
    db_insta_class = get_template_parameter('The database instance type', 'db.t2.micro', 'DBInstanceClass')
    # db_multiaz = get_user_input("The database instance type", "db.t2.micro")
    capacity = get_template_parameter('The initial number of WebServer instances (min: 1, max: 5)', '2', 'WebServerCapacity')
    instance_type = get_template_parameter('WebServer EC2 instance type', 't2.micro', 'InstanceType')
    ssh_location = get_template_parameter('The IP address range that can be used to SSH to the EC2 instances (valid IP CIDR range of the form x.x.x.x/x.)', '0.0.0.0/0', 'SSHLocation')

    cloudformation = Aws::CloudFormation::Client.new
    puts 'Creating new stack'
    resp = cloudformation.create_stack(stack_name: stack_name,
                                       template_url: 'https://s3.eu-central-1.amazonaws.com/cf-templates-1qna2fr92gh55-eu-central-1/drupal-cluster-ubuntu-1404.template',
                                       on_failure: 'ROLLBACK',
                                       parameters: [
                                           ssh_key,
                                           drupal_admin_pass,
                                           drupal_site_name,
                                           db_name,
                                           db_admin,
                                           db_admin_pass,
                                           db_allocated_strorage,
                                           db_insta_class,
                                           capacity,
                                           instance_type,
                                           ssh_location
                                       ])
    cloudformation.wait_until(:stack_create_complete, {stack_name: stack_name}) do |w|
      w.max_attempts = nil;
      w.delay = 5;
      w.before_attempt do |n|
        client = Aws::CloudFormation::Client.new
        stack_events = client.describe_stack_events({stack_name: stack_name})
        stack_events.stack_events.reverse.each do |ev|
          puts "#{ev.timestamp}  #{ev.resource_status}  #{ev.resource_type} #{ev.logical_resource_id}  #{ev.resource_status_reason}"
        end
      end
    end
    puts 'Stack creation is done.'
    resp = cloudformation.describe_stacks(stack_name: stack_name)
    resp.stacks.each do |stack|
      puts "ID: #{stack.stack_id}"
      puts "Name: #{stack.stack_name}"
      puts "Creation time: #{stack.creation_time}"
      puts 'Parameters:'
      stack.parameters.each do |p|
        puts "  #{p.parameter_key}: #{p.parameter_value}"
      end
      puts 'Outputs:'
      stack.outputs.each do |o|
        puts "  #{o.output_key}: #{o.output_value}"
      end
    end
  end

  desc 'stack_info', 'info about all created stacks'
  def stack_info
    cloudformation = Aws::CloudFormation::Client.new
    resp = cloudformation.describe_stacks
    puts 'No stacks.' if resp.stacks.empty?
    resp.stacks.each do |stack|
      puts "Name: #{stack.stack_name}"
      puts "Creation time: #{stack.creation_time}"
      puts "Status: #{stack.stack_status}"
      puts 'Parameters:'
      stack.parameters.each do |p|
        puts "  #{p.parameter_key}: #{p.parameter_value}"
      end
      puts 'Outputs:'
      stack.outputs.each do |o|
        puts "  #{o.output_key}: #{o.output_value}"
      end
    end
  end

  no_commands do
    def get_instance_id(options)
      instance_id = options[:instance_id]
      unless instance_id
        info
        puts TYPE_INSTANCE_ID
        instance_id = STDIN.gets.chomp
      end
      instance_id
    end

    def get_host(options)
      host = options[:host]
      unless host
        info
        puts TYPE_PUBLIC_IP
        host = STDIN.gets.chomp
      end
      host
    end

    def get_user_input(message, default)
      puts message + "(#{default})"
      ret_val = STDIN.gets.chomp
      if ret_val.empty?
        default
      else
        ret_val
      end
    end

    def get_template_parameter(message, default, key)
      value = get_user_input(message, default)
      {
          parameter_key: key,
          parameter_value: value,
          use_previous_value: false
      }
    end
  end
end
AwsCli.start(ARGV)
