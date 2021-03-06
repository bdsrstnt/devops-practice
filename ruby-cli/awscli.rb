#!/usr/bin/ruby
require 'aws-sdk'
require 'thor'
require 'net/http'


class String
  def underscore
    word = self.dup
    word.gsub!(/::/, '/')
    word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
    word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
    word.tr!("-", "_")
    word.downcase!
    word
  end
end

# check aws access data
if !ENV.key?(:AWS_CLI_ID.to_s) || !ENV.key?(:AWS_CLI_SECRET.to_s) || !ENV.key?(:AWS_REGION.to_s)
  raise 'Set ENV entries: AWS_CLI_ID , AWS_CLI_SECRET, AWS_REGION'
end

Aws.config.update(access_key_id: ENV[:AWS_CLI_ID.to_s],
                  secret_access_key: ENV[:AWS_CLI_SECRET.to_s],
                  region: ENV[:AWS_REGION.to_s])

# Class to create Drupal cluster in AWS cloud.
class AwsCli < Thor
  desc 'drupal_status [HOST]', 'Check drupal status. HOST can be public IP or DNS'
  def drupal_status?(host)
    host = 'http://' + host unless host.start_with?('http://')
    begin
      res = Net::HTTP.get_response(URI("#{host}/drupal/"))
    rescue Errno::ECONNREFUSED
      return false
    end
    puts res.body
    puts "Returned HTTP status code: #{res.code}"
    puts "Expires header: #{res['expires']}"
    puts 'Looks OK.' if res['expires'].eql? 'Sun, 19 Nov 1978 05:00:00 GMT'
    retval = res.code.eql?('200') && res.body.include?('name="Generator" content="Drupal')
    puts retval
    retval
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
    instance_id = get_instance_id(options)
    reboot_instance(instance_id)
  end

  desc 'start', 'Start an instance'
  method_option :instance_id, desc: 'Specifiy which instance to start.'
  def start
    ec2 = Aws::EC2::Resource.new
    i = ec2.instance(get_instance_id(options))
    if i.exists?
      case i.state.code
      when 0 # pending
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
    instance_id = get_instance_id(options)
    stop_instance(instance_id)
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
    base_instance_template_url = 'https://s3.eu-central-1.amazonaws.com/cf-templates-1qna2fr92gh55-eu-central-1/update/drupal_recipe.tpl'
    cluster_template_url = 'https://s3.eu-central-1.amazonaws.com/cf-templates-1qna2fr92gh55-eu-central-1/update/drupal_cluster.tpl'
    cloudformation = Aws::CloudFormation::Client.new
    tpl = cloudformation.get_template_summary(template_url: cluster_template_url)
    parameters = []
    tpl.parameters.each do |p|
      unless options[p.parameter_key.underscore].nil? || p.parameter_key.underscore.eql?(:web_server_capacity)
        parameters.push(get_template_parameter(p.parameter_key, options[p.parameter_key.underscore]))
      end
    end
    stack_name = options[:stack_name] || :myStack
    puts "Creating new stack #{stack_name}"
    resp = cloudformation.create_stack(stack_name: stack_name,
                                       template_url: cluster_template_url,
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

    base_instance_stack_name = stack_name + 'baseInstance'
    puts "Creating base instance with stack #{base_instance_stack_name}"
    # get databse url and port
    drupal_install_parameters = [
      get_template_parameter(:DBEndpoint, get_output_from_stack(stack_name, 'DBUrl', cloudformation)),
      get_template_parameter(:DBPort, get_output_from_stack(stack_name, 'DBPort', cloudformation)),
      get_template_parameter(:DrupalAdminPassword, options[:drupal_admin_password])
    ]
    drupal_install_parameters.push(get_template_parameter(:DrupalSiteName, options[:drupal_site_name])) unless options[:drupal_site_name].nil?
    
    # create the base instance
    resp = cloudformation.create_stack(stack_name: base_instance_stack_name,
                                       template_url: base_instance_template_url,
                                       on_failure: 'ROLLBACK',
                                       parameters: parameters + drupal_install_parameters)
    cloudformation.wait_until(:stack_create_complete, stack_name: base_instance_stack_name) do |w|
      w.max_attempts = nil
      w.delay = 5
      w.before_attempt do |_n|
        describe_stack_events(cloudformation, base_instance_stack_name)
      end
    end

    ip = get_output_from_stack(base_instance_stack_name, 'InstanceIP', cloudformation)
    ec2Resource = Aws::EC2::Resource.new
    image_this = ec2Resource.instances.detect { |i| i.public_ip_address.eql? ip }
    ec2Client = Aws::EC2::Client.new
    puts "Waiting for intance #{image_this.id} to finish startup"
    ec2Client.wait_until(:instance_status_ok, instance_ids: [image_this.id]) do |w|
      w.max_attempts = nil
      w.delay = 5
    end
    # wait until drupal install is complete
    max_attempts = 30
    current_attempt = 1
    while !drupal_status?(ip) && current_attempt < max_attempts
      puts "Checking Drupal status... #{current_attempt}"
      sleep(10)
      current_attempt += 1
    end

    unless current_attempt != max_attempts
      raise "Drupal installation error on IP #{ip}"
    end

    puts 'Drupal is ok.'
    puts 'Base stack creation done. Creating new EC2 image...'
    puts 'Starting AMI creation.'

    puts "Creating image from instance: #{image_this.id}"
    imageResp = ec2Client.create_image(dry_run: false,
                                       instance_id: image_this.id,
                                       name: stack_name + image_this.id + 'image')
    puts "Image id is #{imageResp.image_id}. Waiting for image to be available."
    ec2Client.wait_until(:image_available, image_ids: [imageResp.image_id]) do |w|
      w.max_attempts = nil
      w.delay = 5
    end

    puts 'Deleting base instance stack'
    delete_stack(base_instance_stack_name)

    puts "Image is available. Creating Drupal cluster based on image #{imageResp.image_id}"

    # Update the cluster stack with image
    web_server_capacity = options[:web_server_capacity] || '2'
    parameters.push(get_template_parameter(:WebServerCapacity, web_server_capacity))
    parameters.push(get_template_parameter(:AMIImageId, imageResp.image_id))
    cloudformation.update_stack(stack_name: stack_name,
                                parameters: parameters,
                                template_url: cluster_template_url)

    cloudformation.wait_until(:stack_update_complete, stack_name: stack_name) do |w|
      w.max_attempts = nil
      w.delay = 5
      w.before_attempt do |_n|
        describe_stack_events(cloudformation, stack_name)
      end
    end

    # check cluster
    resp = cloudformation.describe_stacks(stack_name: stack_name)
    stack = resp.stacks[0]
    output = stack.outputs.detect { |o| o[:output_key].eql? 'WebsiteURL' }
    elbDns = output.output_value
    puts "Checking drupal installation on loadbalancer #{elbDns}"
    current_attempt = 1
    while !drupal_status?(elbDns) && current_attempt < max_attempts
      puts "Checking Drupal status... #{current_attempt}"
      sleep(10)
      current_attempt += 1
    end
    if current_attempt == max_attempts
      raise 'An error occured while checking the Drupal cluster. Please check your AWS console.'
    end
    puts "Drupal cluster is ready to use on: #{elbDns}/drupal"
  end

  desc 'delete_stack [STACK_NAME]', 'Deletes the specified stack'
  def delete_stack(stack_name)
    cloudformation = Aws::CloudFormation::Client.new
    cloudformation.delete_stack(stack_name: stack_name)
    puts "Deleting stack #{stack_name}"
  end

  no_commands do
    def get_output_from_stack(stack_name, output_name, cloudformation)
      resp = cloudformation.describe_stacks(stack_name: stack_name)
      stack = resp.stacks[0]
      output = stack.outputs.detect { |o| o[:output_key].eql? output_name }
      output.output_value
    end

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
      unless filter.empty?
        stack_events = stack_events.select { |ev| ev[:resource_status].start_with?(filter[0].to_s) }
      end
      stack_events.reverse.each do |ev|
        puts "#{ev.timestamp}  #{ev.resource_status}  #{ev.resource_type} #{ev.logical_resource_id}  #{ev.resource_status_reason}"
      end
      puts '--'
    end

    def get_template_parameter(key, value)
      {
        parameter_key: key,
        parameter_value: value,
        use_previous_value: false
      }
    end

    def stop_instance(instance_id)
      ec2 = Aws::EC2::Resource.new
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

    def reboot_instance(instance_id)
      ec2 = Aws::EC2::Resource.new
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

    def terminate_instance(instance_id)
      ec2 = Aws::EC2::Resource.new
      i = ec2.instance(instance_id)
      if i.exists?
        i.terminate
        puts "Terminating instance #{instance_id}"
      end
    end
  end
end
AwsCli.start(ARGV)
