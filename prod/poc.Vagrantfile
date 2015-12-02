# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  config.vm.box = "ubuntu/trusty64"

  if Vagrant.has_plugin?("vagrant-cachier")
    # Configure cached packages to be shared between instances of the same base box.
    # More info on http://fgrehm.viewdocs.io/vagrant-cachier/usage
    config.cache.scope = :box
  end

  config.ssh.insert_key = false

  cluster = {
    "zk1" => "192.168.33.11",
    "zk2" => "192.168.33.12",
    "mm1" => "192.168.33.21",
    "ms1" => "192.168.33.31"
  }

  cluster.each_with_index do | (hostname, ipaddr), index |
    config.vm.define hostname do | host |
      host.vm.hostname = hostname
      host.vm.network "private_network", ip: ipaddr
      # if index == cluster.size - 1
      #   config.vm.provision :ansible do |ansible|
      #     # Disable default limit to connect to all the machines
      #     ansible.limit = 'all'
      #     ansible.playbook = "provisioning/playbook.yml"
      #     ansible.inventory_path = "ansible_inventory"
      #   end
      # end
    end
  end

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"


end
