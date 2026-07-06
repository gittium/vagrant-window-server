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
| `config.json`                     | **Edit this** to control everything: RAM, CPU, disk size, number of VMs. |
| `Vagrantfile`                     | Reads `config.json` and builds the VMs accordingly. You shouldn't need to edit this. |
| `provision/format-datadisk.ps1`   | Formats the optional extra data disk (drive letter from config), if one was attached. No-op otherwise. |
| `provision/install-sqlserver.ps1` | Runs inside the guest to install SQL Server 2016.         |
| `media/`                          | Put SQL Server installer ISOs/exes here (synced to the VM as `C:\media`). Not committed to git. |

## Configuration — `config.json`

Everything about how many servers you get and how big they are lives in
`config.json`, not the Vagrantfile:

```json
{
  "sa_password": "Str0ng!Passw0rd",
  "servers": [
    { "name": "testdb1", "ram_mb": 4096, "cpus": 2, "data_disk_gb": 0 },
    { "name": "testdb2", "ram_mb": 8192, "cpus": 4, "data_disk_gb": 200, "data_disk_letter": "E" }
  ]
}
```

| Field | Meaning |
|---|---|
| `sa_password` | Shared SQL `sa` login password for every server |
| `servers` | One entry per VM you want. Add or remove entries to control how many you get. |
| `name` | VM name — used for `vagrant up <name>`, `vagrant rdp <name>`, etc. |
| `ram_mb` | RAM in MB. SQL Server wants at least 4096. |
| `cpus` | Virtual CPU cores. |
| `data_disk_gb` | `0` = just the 125 GB OS disk (default). Any number > 0 attaches a second disk of that size, with SQL Server's data/log/tempdb pointed there — see "Need more than 125 GB?" below. |
| `data_disk_letter` | Drive letter for the data disk (default `"D"` if omitted). Must be `D`-`Z` — `C` is rejected since it's the OS drive. Ignored if `data_disk_gb` is `0`. |

Each server's private IP and forwarded SQL port are assigned automatically
based on its position in the list (1st server → `192.168.56.21` / host port
`14330`, 2nd → `.22` / `14331`, etc.) — nothing to manage by hand there.

## Usage

```powershell
# From C:\vagrant-window
vagrant up                 # build + provision every server in config.json
vagrant up testdb1          # build/provision just one
vagrant rdp testdb1          # remote-desktop into it (recommended, see gotcha below)
vagrant powershell testdb1  # PowerShell prompt inside it
vagrant halt testdb1        # graceful shutdown of just that one
vagrant destroy -f testdb1  # delete just that one (box stays cached)
vagrant status               # see the state of every server
```

To change RAM/CPU/disk size or add another server: edit `config.json`, then
`vagrant reload --provision <name>` (existing VM) or `vagrant up <name>` (new one).

## Need more than 125 GB of disk?

The OS disk is a fixed 125 GB (VirtualBox dynamically-allocated — only actually
used space counts against your host disk, up to that cap). If you need more
room for a large test database, set `data_disk_gb` (and optionally
`data_disk_letter`) on that server in `config.json` (see table above) — it
attaches a second disk, auto-formats it under the chosen letter, and points
SQL Server's data/log/tempdb at `<letter>:\SQLData`, `<letter>:\SQLLogs`,
`<letter>:\TempDB` automatically. Leave `data_disk_gb` at `0` for the normal
single-disk setup.

## Connecting to SQL Server

For the example two-server `config.json` above:

| Server | Hostname | Private IP | Host SQL port |
|---|---|---|---|
| `testdb1` | `TESTDB1` | `192.168.56.21` | `localhost,14330` |
| `testdb2` | `TESTDB2` | `192.168.56.22` | `localhost,14331` |

- **Login:** SQL auth — user `sa`, password from `config.json`'s `sa_password`
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

- **Ctrl+Alt+Del / lock screen:** if you open the VirtualBox console window
  (the GUI, `vb.gui = true`) instead of using `vagrant rdp`, Windows shows its
  normal login lock screen requiring Ctrl+Alt+Del. Your host OS intercepts the
  physical key combo, so it never reaches the VM. Either use the VirtualBox
  menu **Input → Keyboard → Insert Ctrl-Alt-Del**, or just avoid the whole
  problem by using `vagrant rdp <name>` instead, which shows a normal login
  prompt with no SAS forwarding needed. Login is `vagrant` / `vagrant`.
- Windows guests use **WinRM**, not SSH — that's already set in the Vagrantfile.
- First `vagrant up` is slow (large box download + SQL install). Later runs are fast.
- If provisioning fails midway, fix the script and run `vagrant provision` — the
  install script is idempotent and skips SQL if it's already there.
- To switch to VMware later: install the `vagrant-vmware-desktop` plugin (paid) +
  VMware Utility, then change the provider block to `config.vm.provider "vmware_desktop"`.
