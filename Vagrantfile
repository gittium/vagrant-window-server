# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# Windows Server 2019 + SQL Server 2016 lab
# Provider: VirtualBox (free)
#
# Quick start:
#   vagrant up            # build the VM and run provisioning
#   vagrant rdp            # open a Remote Desktop session
#   vagrant powershell    # open a PowerShell session inside the guest
#   vagrant halt          # shut the VM down
#   vagrant destroy -f    # delete the VM completely

Vagrant.configure("2") do |config|
  # A well-maintained Windows Server 2019 Standard base box (has a GUI).
  # First run downloads ~10 GB, so be patient the first time.
  config.vm.box = "gusztavvargadr/windows-server-2019-standard"

  # Windows guests talk to Vagrant over WinRM, not SSH.
  config.vm.communicator = "winrm"
  config.vm.guest = :windows
  config.winrm.username = "vagrant"
  config.winrm.password = "vagrant"

  # Give provisioning plenty of time (boot + SQL install is slow).
  config.vm.boot_timeout = 600
  config.winrm.timeout   = 1800

  # A friendly hostname and a private network so you can reach SQL from the host.
  config.vm.hostname = "SQL2016LAB"
  config.vm.network "private_network", ip: "192.168.56.20"

  # Forward the SQL Server port to the host (host 14330 -> guest 1433).
  config.vm.network "forwarded_port", guest: 1433, host: 14330, id: "mssql"

  # Share the local media folder (put SQL Server installers/ISOs here) into the guest.
  config.vm.synced_folder "media", "C:/media", create: true

  config.vm.provider "virtualbox" do |vb|
    vb.name   = "WinServer2019-SQL2016"
    vb.gui    = true      # set to false for a headless VM
    vb.memory = 4096      # SQL Server wants RAM; 4 GB is a sane minimum
    vb.cpus   = 2
  end

  # Provision: install SQL Server 2016 Developer Edition via PowerShell.
  # Reads the ISO from .\media (synced folder above) — see provision script.
  # The SA_PASSWORD env var lets you override the default password below.
  config.vm.provision "shell",
    path: "provision/install-sqlserver.ps1",
    args: [ENV.fetch("SA_PASSWORD", "Str0ng!Passw0rd")]
end
