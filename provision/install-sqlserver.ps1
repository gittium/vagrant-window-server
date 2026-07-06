<#
    install-sqlserver.ps1
    Runs INSIDE the Windows Server 2019 guest during `vagrant up`.
    Mounts the SQL Server 2016 Developer Edition ISO (synced in from the
    host's .\media folder) and silently installs it.

    Arg 1: the SA (sysadmin) password for SQL authentication.
    Arg 2: drive letter the data disk was formatted as (see format-datadisk.ps1).
#>
param(
    [string]$SaPassword = "Str0ng!Passw0rd",
    [string]$DataDriveLetter = "D"
)

$ErrorActionPreference = "Stop"
Set-ExecutionPolicy Bypass -Scope Process -Force

# Skip everything if SQL is already installed (makes re-provisioning safe/idempotent).
if (Get-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue) {
    Write-Host "SQL Server (MSSQLSERVER) already installed. Nothing to do."
    exit 0
}

$sharedIsoPath = "C:\media\SQLServer2016SP3-FullSlipstream-x64-ENU-DEV.iso"
if (-not (Test-Path $sharedIsoPath)) {
    throw "Could not find $sharedIsoPath. Make sure the ISO is in the project's .\media folder on the host (synced to C:\media in the guest)."
}

# Mount-DiskImage can't mount a file sitting on a VirtualBox shared folder
# (Windows treats it as a network path). Copy it to local disk first.
$localIsoPath = "C:\sql-install\sqlserver2016-dev.iso"
New-Item -ItemType Directory -Force -Path (Split-Path $localIsoPath) | Out-Null
if (-not (Test-Path $localIsoPath)) {
    Write-Host "Copying ISO from shared folder to local disk..."
    Copy-Item -Path $sharedIsoPath -Destination $localIsoPath
}

Write-Host "Mounting SQL Server installer ISO..."
$mount     = Mount-DiskImage -ImagePath $localIsoPath -PassThru
$driveInfo = $mount | Get-Volume
$sqlDrive  = "$($driveInfo.DriveLetter):"

try {
    Write-Host "Installing SQL Server 2016 Developer Edition (this takes several minutes)..."
    $setupArgs = @(
        "/Q"                                             # quiet, no UI
        "/ACTION=Install"
        "/IACCEPTSQLSERVERLICENSETERMS"
        "/FEATURES=SQLENGINE,FULLTEXT,AS,RS"             # engine + full-text + Analysis + Reporting Services
        "/INSTANCENAME=MSSQLSERVER"
        "/SQLSVCACCOUNT=`"NT AUTHORITY\SYSTEM`""
        "/SQLSYSADMINACCOUNTS=`"BUILTIN\Administrators`""
        "/SECURITYMODE=SQL"                              # enable mixed-mode auth
        "/SAPWD=`"$SaPassword`""                         # SA account password
        "/TCPENABLED=1"                                  # turn on the TCP/IP protocol
        "/NPENABLED=0"
        "/ASSVCACCOUNT=`"NT AUTHORITY\SYSTEM`""
        "/RSSVCACCOUNT=`"NT AUTHORITY\SYSTEM`""
        "/ASSYSADMINACCOUNTS=`"BUILTIN\Administrators`""
    )

    # If an extra data disk was formatted (see format-datadisk.ps1),
    # point SQL Server's data/log/tempdb files there instead of C:.
    if (Test-Path "${DataDriveLetter}:\SQLData") {
        $setupArgs += "/SQLUSERDBDIR=${DataDriveLetter}:\SQLData"
        $setupArgs += "/SQLUSERDBLOGDIR=${DataDriveLetter}:\SQLLogs"
        $setupArgs += "/SQLTEMPDBDIR=${DataDriveLetter}:\TempDB"
    }

    $setup = Join-Path $sqlDrive "setup.exe"
    $p = Start-Process -FilePath $setup -ArgumentList $setupArgs -Wait -PassThru
    if ($p.ExitCode -ne 0) {
        throw "SQL Server setup failed with exit code $($p.ExitCode). See C:\Program Files\Microsoft SQL Server\130\Setup Bootstrap\Log\Summary.txt"
    }
}
finally {
    Write-Host "Unmounting installer ISO..."
    Dismount-DiskImage -ImagePath $localIsoPath | Out-Null
    Remove-Item -Path $localIsoPath -Force -ErrorAction SilentlyContinue
}

# Make sure the service is running and set to auto-start.
Set-Service -Name "MSSQLSERVER" -StartupType Automatic
Start-Service -Name "MSSQLSERVER"

# Open the firewall so the host can connect on port 1433.
New-NetFirewallRule -DisplayName "SQL Server (TCP 1433)" `
    -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow -ErrorAction SilentlyContinue | Out-Null

Write-Host ""
Write-Host "=================================================="
Write-Host " SQL Server 2016 Developer Edition installed successfully."
Write-Host "   Instance : SQL2016LAB\MSSQLSERVER (default instance)"
Write-Host "   Features : Database Engine, Full-Text, Analysis Services, Reporting Services"
Write-Host "   Login    : sa"
Write-Host "   Password : $SaPassword"
Write-Host "=================================================="
