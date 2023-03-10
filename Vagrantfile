# -*- mode: ruby -*-
# vi: set ft=ruby :
BOX_RAM = 2048
BOX_CPU = 2
Vagrant.configure(2) do |config|
  config.vm.define "rocky9" do |rk|
    rk.vm.box = "kgeor/rocky9-kernel6"
    rk.vm.synced_folder ".", "/vagrant"
    rk.vm.provider "virtualbox" do |vb|
      vb.name = "rocky9-raid"
      vb.memory = BOX_RAM
      vb.cpus = BOX_CPU
      (1..3).each do |i|
        unless File.exist?("disk-#{i}.vdi")
          vb.customize [ "createmedium", "disk", "--filename", "disk-#{i}.vdi", "--format", "vdi", "--size", "250"]
        end
        vb.customize [ "storageattach", :id, "--storagectl", "SATA Controller", "--port", "#{i}", "--device", 0, "--type", "hdd", "--medium", "disk-#{i}.vdi"]
      end
    end
  # hostname виртуальной машины
  rk.vm.hostname = "rocky9-raid"
  rk.vm.provision "shell", path: "./create_raid.sh"
  end
end