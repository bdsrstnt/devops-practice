require "aws-sdk"
require "thor"
require "net/http"

AWS_CLI_ID = 'AWS_CLI_ID';
AWS_CLI_SECRET = 'AWS_CLI_SECRET';

# check aws access data
if(!ENV.has_key?(AWS_CLI_ID) || !ENV.has_key?(AWS_CLI_SECRET))
  raise "Please set the following ENV entries: #{AWS_CLI_ID} , #{AWS_CLI_SECRET}"
end

Aws.config.update({
                      :access_key_id => ENV[AWS_CLI_ID],
                      :secret_access_key => ENV[AWS_CLI_SECRET],
                      :region => 'eu-central-1'
                  })


class AwsCli < Thor

  desc "hello NAME", "say hello to NAME"
  def hello(name)
    puts "Hello #{name}"
  end

  desc "get URL", "do http GET to URL"
  def get(url)
    uri = URI(url)
    res = Net::HTTP.get_response(uri)
    puts res.body
    puts res.code
  end

  desc "info", "get info about instances"
  def info()
    ec2 = Aws::EC2::Resource.new()

    # To only get the first 10 instances: ec2.instances.limit(10).each do |i|
    ec2.instances.each do |i|
      puts "ID: #{i.id}"
      puts "State: #{i.state.name}"
    end
  end

  desc "reboot INSTANCENAME", "reboots instance named INSTANCENAME"
  def reboot(instanceName)
    ec2 = Aws::EC2::Resource.new()

    i = ec2.instance(instanceName)

    if i.exists?
      case i.state.code
        when 48 # terminated
          puts "#{id} is terminated, so you cannot reboot it"
        else
          i.reboot
      end
    end
  end

  desc "start INSTANCENAME", "start instance name NSTANCENAME"
  def start(instanceName)
    ec2 = Aws::EC2::Resource.new()

    i = ec2.instance(instanceName)

    if i.exists?
      case i.state.code
        when 0  # pending
          puts "#{id} is pending, so it will be running in a bit"
        when 16  # started
          puts "#{id} is already started"
        when 48  # terminated
          puts "#{id} is terminated, so you cannot start it"
        else
          i.start
      end
    end
  end

  desc "stop INSTANCENAME", "stop instance name INSTANCENAME"
  def stop(instanceName)
    ec2 = Aws::EC2::Resource.new()

    i = ec2.instance(instanceName)

    if i.exists?
      case i.state.code
        when 48  # terminated
          puts "#{id} is terminated, so you cannot stop it"
        when 64  # stopping
          puts "#{id} is stopping, so it will be stopped in a bit"
        when 89  # stopped
          puts "#{id} is already stopped"
        else
          i.stop
      end
    end

  end
end
AwsCli.start(ARGV)

