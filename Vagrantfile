# -*- mode: ruby -*-
# vi: set ft=ruby :
#
require "json"
require "fileutils"
#
# Windows Server 2019 + SQL Server 2016 lab
# Provider: VirtualBox (free)
#
# All settings live in config.json, NOT in this file. To change RAM, CPU,
# add a data disk, or add/remove test-server instances, edit config.json —
# never edit this Vagrantfile itself.
#
#   config.json:
#     {
#       "sa_password": "...",                                <- shared SQL 'sa' login password
#       "servers": [
#         { "name": "testdb1", "ram_mb": 4096, "cpus": 2, "data_disk_gb": 0 },
#         { "name": "testdb2", "ram_mb": 8192, "cpus": 4, "data_disk_gb": 200 }
#       ]
#     }
#
#   - Add/remove entries in "servers" to control how many VMs you get.
#   - data_disk_gb: 0 (or omit it) = no extra disk, just the 125GB OS disk.
#     Any number > 0 attaches a second disk of that size, auto-formatted with
#     SQL Server's data/log/tempdb directories pointed there.
#   - data_disk_letter: which drive letter to format the data disk as
#     (defaults to "D" if omitted). Ignored if data_disk_gb is 0.
#   - Each server's private IP and forwarded SQL port are assigned
#     automatically based on its position in the list — no need to manage
#     those numbers by hand.
#
# Quick start:
#   vagrant up                 # build and provision every server in config.json
#   vagrant up testdb1          # build/provision just one named server
#   vagrant rdp testdb1          # open a Remote Desktop session to it
#   vagrant powershell testdb1  # open a PowerShell session inside it
#   vagrant halt testdb1        # shut just that one down
#   vagrant destroy -f testdb1  # delete just that one
#   vagrant status               # see the state of every server

CONFIG_PATH = File.join(File.dirname(__FILE__), "config.json")
unless File.exist?(CONFIG_PATH)
  raise "config.json not found in #{File.dirname(__FILE__)}. See the project README for the expected format."
end
USER_CONFIG = JSON.parse(File.read(CONFIG_PATH))

SA_PASSWORD = USER_CONFIG.fetch("sa_password", "Str0ng!Passw0rd")
SERVERS     = USER_CONFIG.fetch("servers", [])

Vagrant.configure("2") do |config|
  SERVERS.each_with_index do |server, index|
    name             = server.fetch("name")
    ram_mb           = server.fetch("ram_mb", 4096)
    cpus             = server.fetch("cpus", 2)
    data_disk_gb     = server.fetch("data_disk_gb", 0).to_i
    data_disk_letter = server.fetch("data_disk_letter", "D").upcase
    ip_suffix        = 21 + index
    port_offset      = index

    if data_disk_gb > 0
      unless data_disk_letter =~ /\A[D-Z]\z/
        raise "#{name}: data_disk_letter must be a single letter D-Z (got #{data_disk_letter.inspect}). C is reserved for the OS disk."
      end
    end

    config.vm.define name do |node|
      # A well-maintained Windows Server 2019 Standard base box (has a GUI).
      # First run downloads ~10 GB, so be patient the first time — after
      # that, every additional server clones from the same cached box.
      node.vm.box = "gusztavvargadr/windows-server-2019-standard"

      # Windows guests talk to Vagrant over WinRM, not SSH.
      node.vm.communicator = "winrm"
      node.vm.guest = :windows
      node.winrm.username = "vagrant"
      node.winrm.password = "vagrant"

      # Give provisioning plenty of time (boot + SQL install is slow).
      node.vm.boot_timeout = 600
      node.winrm.timeout   = 1800

      # Unique hostname and private-network IP per server.
      node.vm.hostname = name.upcase
      node.vm.network "private_network", ip: "192.168.56.#{ip_suffix}"

      # Forward this server's SQL port to a unique host port
      # (1st server -> 14330, 2nd -> 14331, etc.) so they never clash.
      node.vm.network "forwarded_port",
        guest: 1433,
        host: 14330 + port_offset,
        id: "mssql",
        auto_correct: true

      # Share the local media folder (put SQL Server installers/ISOs here)
      # into every guest — all servers read the same ISO from the host.
      node.vm.synced_folder "media", "C:/media", create: true

      node.vm.provider "virtualbox" do |vb|
        vb.name   = "WinServer2019-SQL2016-#{name}"
        vb.gui    = true      # each server gets its own VirtualBox window
        vb.memory = ram_mb
        vb.cpus   = cpus

        # Optional data disk — only attached if data_disk_gb > 0 in config.json.
        if data_disk_gb > 0
          disk_dir  = File.join(Dir.pwd, ".vagrant", "disks")
          disk_path = File.join(disk_dir, "#{name}-data.vdi")
          FileUtils.mkdir_p(disk_dir)
          unless File.exist?(disk_path)
            vb.customize ["createhd", "--filename", disk_path, "--size", data_disk_gb * 1024]
            vb.customize ["storageattach", :id,
              "--storagectl", "SATA Controller",
              "--port", "1", "--device", "0",
              "--type", "hdd", "--medium", disk_path]
          end
        end
      end

      # Provision: format the optional data disk (no-op if none was attached),
      # then install SQL Server 2016 Developer Edition via PowerShell.
      # Reads the ISO from .\media (synced folder above) — see provision scripts.
      node.vm.provision "shell",
        path: "provision/format-datadisk.ps1",
        args: [data_disk_letter]
      node.vm.provision "shell",
        path: "provision/install-sqlserver.ps1",
        args: [SA_PASSWORD, data_disk_letter]
    end
  end
end
