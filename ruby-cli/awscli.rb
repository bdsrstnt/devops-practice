#!/usr/bin/ruby
require 'aws-sdk'
require 'thor'
require 'net/http'
require 'active_support/core_ext/string'

# check aws access data
if !ENV.key?(:AWS_CLI_ID.to_s) || !ENV.key?(:AWS_CLI_SECRET.to_s) || !ENV.key?(:AWS_REGION.to_s)
  raise 'Set ENV entries: :AWS_CLI_ID , AWS_CLI_SECRET, AWS_REGION'
end

Aws.config.update(access_key_id: ENV[:AWS_CLI_ID.to_s],
                  secret_access_key: ENV[:AWS_CLI_SECRET.to_s],
                  region: ENV[:AWS_REGION.to_s])

# Class to get info and interact with AWS EC2 instances and auto scaling groups.
class AwsCli < Thor
  desc 'drupal_status [HOST]', 'Check drupal status. HOST can be public IP or DNS'
  def drupal_status(host)
    host = 'http://' + host unless host.start_with?('http://')
    res = Net::HTTP.get_response(URI("#{host}/drupal/"))
    puts res.body
    puts "Returned HTTP status code: #{res.code}"
    puts "Expires header: #{res["expires"]}"
    if res["expires"].eql? 'Sun, 19 Nov 1978 05:00:00 GMT'
      puts "Looks OK."
    end
  end

  desc 'info', 'Get info about instances'
  def info
    ec2 = Aws::EC2::Resource.new
    ec2.instances.each do |i|
      puts '--'
      puts "Instance ID: #{i.id}"
      puts "State: #{i.state.name}"
      puts "Public IP: #{i.public_ip_address}"
    end
  end

  desc 'reboot', 'Reboots an instance'
  method_option :instance_id, desc: 'Specifiy which instance to start.'
  def reboot
    ec2 = Aws::EC2::Resource.new
    i = ec2.instance(get_instance_id(options))
    if i.exists?
      case i.state.code
      when 48 # terminated
        puts "#{instance_id} is terminated, so you cannot reboot it"
      else
        i.reboot
      end
    end
  end

  desc 'start', 'Start an instance'
  method_option :instance_id, desc: 'Specifiy which instance to start.'
  def start
    ec2 = Aws::EC2::Resource.new
    i = ec2.instance(get_instance_id(options))
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

  desc 'stop', 'Stop an instance'
  method_option :instance_id, desc: 'Specifiy which instance to stop.'
  def stop
    ec2 = Aws::EC2::Resource.new
    i = ec2.instance(get_instance_id(options))
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

  desc 'autoscale_info', 'Prints information about autoscaling groups.'
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
      lbresp = client.describe_load_balancers(load_balancer_names: autoscalinggroup.load_balancer_names)
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

  desc 'setup_drupal_ha_cluster', 'Sets up a drupal cluster with CloudFormation'
  method_option :stack_name, desc: 'Name of the stack. Default: myStack'
  method_option :key_name, desc: 'Name of the key-pair, which can be used to connect via SSH.'
  method_option :drupal_admin_password, desc: 'Drupal admin password'
  method_option :drupal_site_name, desc: 'Drupal site name. Default: My Drupal Site'
  method_option :db_name, desc: 'DB name. Default: myDatabase'
  method_option :db_user, desc: 'DB admin user name'
  method_option :db_password, desc: 'DB admin password'
  method_option :db_allocated_storage, desc: 'Db size (Gb). Default: 5'
  method_option :db_instance_class, desc: 'DB instance class. Default: db.t2.micro'
  method_option :web_server_capacity, desc: 'Webserver capacity, between 1-5. Default: 2'
  method_option :instance_type, desc: 'EC2 instance type. Default: t2.micro'
  method_option :ssh_location, desc: 'Allowed IP\'s for SSH, in valid IP CIDR range (x.x.x.x/x). Default: 0.0.0.0/0'
  def setup_drupal_ha_cluster
    template_url = 'https://s3.eu-central-1.amazonaws.com/cf-templates-1qna2fr92gh55-eu-central-1/drupal-cluster-ubuntu-1404.template'
    cloudformation = Aws::CloudFormation::Client.new
    tpl = cloudformation.get_template_summary(template_url: template_url)
    parameters = []
    tpl.parameters.each do |p|
      parameters.push(parameter_key: p.parameter_key,
                      parameter_value: options[p.parameter_key.underscore],
                      use_previous_value: false) unless options[p.parameter_key.underscore].nil?
    end
    stack_name = options[:stack_name] || :myStack
    puts "Creating new stack #{stack_name}"
    resp = cloudformation.create_stack(stack_name: stack_name,
                                       template_url: template_url,
                                       on_failure: 'ROLLBACK',
                                       parameters: parameters)
    cloudformation.wait_until(:stack_create_complete, stack_name: stack_name) do |w|
      w.max_attempts = nil
      w.delay = 5
      w.before_attempt do |_n|
        describe_stack_events(cloudformation, stack_name)
      end
    end
    puts "Creating stack #{stack_name} is succesful."
    stack = stack_info(stack_name)
  end

  desc 'delete_stack [STACK_NAME]', 'Deletes the specified stack'
  def delete_stack(stack_name)
    cloudformation = Aws::CloudFormation::Client.new
    cloudformation.delete_stack({
      stack_name: stack_name
    })
    puts "Deleting stack #{stack_name}"
    cloudformation.wait_until(:stack_delete_complete, stack_name: stack_name) do |w|
      w.max_attempts = nil
      w.delay = 5
      w.before_attempt do |_n|
        describe_stack_events(cloudformation, stack_name, 'DELETE')
      end
    end
  end

  desc 'stack_info [STACK_NAME]', 'Info about the specfied stack'
  def stack_info(stack_name)
    cloudformation = Aws::CloudFormation::Client.new
    resp = cloudformation.describe_stacks(stack_name: stack_name)
    puts 'No stacks.' if resp.stacks.empty?
    stack = resp.stacks[0]
    puts "ID: #{stack.stack_id}"
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
    stack
  end

  no_commands do
    def get_instance_id(options)
      instance_id = options[:instance_id]
      unless instance_id
        info
        puts 'Type instance ID'
        instance_id = STDIN.gets.chomp
      end
      instance_id
    end
    
    def describe_stack_events(client, stack_name, *filter)
        resp = client.describe_stack_events(stack_name: stack_name)
        stack_events = resp.stack_events
        if filter.size() > 0
          stack_events = stack_events.select {|ev| ev[:resource_status].start_with?(filter[0].to_s)}
        end
        stack_events.reverse.each do |ev|
          puts "#{ev.timestamp}  #{ev.resource_status}  #{ev.resource_type} #{ev.logical_resource_id}  #{ev.resource_status_reason}"
        end
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
