# Windows Server 2019 + SQL Server 2016 — Vagrant Lab

A hands-on Vagrant project that builds a **Windows Server 2019** VM in **VirtualBox**
and silently installs SQL Server 2016 Developer Edition.

## Prerequisites (install once)

Run these in an **elevated** PowerShell (Run as Administrator):

```powershell
winget install --id HashiCorp.Vagrant  -e
winget install --id Oracle.VirtualBox   -e
```

Close and reopen your terminal afterwards, then verify:

```powershell
vagrant --version
VBoxManage --version
```

## Files in this project

| File                              | What it does                                            |
|-----------------------------------|-----------------------------------------------------------|
| `Vagrantfile`                     | Defines the VM: box, memory, network, provisioning.       |
| `provision/install-sqlserver.ps1` | Runs inside the guest to install SQL Server 2016.         |
| `media/`                          | Put SQL Server installer ISOs/exes here (synced to the VM as `C:\media`). Not committed to git. |

## Usage

```powershell
# From C:\vagrant-window
vagrant up          # first run downloads the box (~10 GB) + installs SQL
vagrant rdp         # remote-desktop into the running VM
vagrant powershell  # PowerShell prompt inside the guest
vagrant halt        # graceful shutdown
vagrant destroy -f  # delete the VM (box stays cached)
```

Optional: set a custom SA password before `vagrant up`:

```powershell
$env:SA_PASSWORD = "MyStr0ng!Pass"
vagrant up
```

## Connecting to SQL Server

- **From inside the VM:** server `SQL2016LAB` (default instance)
- **From your host machine:** `localhost,14330` (forwarded) or `192.168.56.20` (private network)
- **Login:** SQL auth — user `sa`, password `Str0ng!Passw0rd` (or your `SA_PASSWORD`)
- **Edition/features installed:** Developer Edition — Database Engine, Full-Text, Analysis Services, Reporting Services

## The Vagrant workflow (the core loop to learn)

1. `vagrant init` — create a Vagrantfile.
2. Edit the `Vagrantfile` — declare box, resources, network, provisioning.
3. `vagrant up` — Vagrant builds the VM to match the file.
4. `vagrant provision` — re-run just the provisioning scripts on a running VM.
5. `vagrant reload` — restart, re-reading the Vagrantfile.
6. `vagrant destroy` — tear it all down. Rebuild identically anytime.

The whole point: the VM is **disposable and reproducible**. The Vagrantfile is the
source of truth, so you commit it to git instead of hand-configuring servers.

## SQL Server 2016 Developer Edition

The provisioning script installs from `media\SQLServer2016SP3-FullSlipstream-x64-ENU-DEV.iso`
(free Developer Edition, full Enterprise feature set, licensed for dev/test only — not production).
That ISO must exist in `.\media\` before `vagrant up` — see the "distribution" note below for
why every developer currently needs their own copy.

## Notes / gotchas

- Windows guests use **WinRM**, not SSH — that's already set in the Vagrantfile.
- First `vagrant up` is slow (large box download + SQL install). Later runs are fast.
- If provisioning fails midway, fix the script and run `vagrant provision` — the
  install script is idempotent and skips SQL if it's already there.
- To switch to VMware later: install the `vagrant-vmware-desktop` plugin (paid) +
  VMware Utility, then change the provider block to `config.vm.provider "vmware_desktop"`.
