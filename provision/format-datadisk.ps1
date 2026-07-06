<#
    format-datadisk.ps1
    Runs INSIDE the guest during `vagrant up`, BEFORE the SQL Server install.

    If an extra disk was attached (via data_disk_gb in config.json), this
    initializes it and formats it under the given drive letter. If no extra
    disk is present, or that drive letter is already set up, this is a no-op.

    Arg 1: drive letter to format the data disk as (e.g. "D").
#>
param(
    [string]$DriveLetter = "D"
)

$ErrorActionPreference = "Stop"

if ($DriveLetter -eq "C") {
    throw "data_disk_letter cannot be C — that's the OS drive."
}

if (Test-Path "${DriveLetter}:\") {
    Write-Host "${DriveLetter}: drive already present. Nothing to do."
    exit 0
}

$rawDisk = Get-Disk | Where-Object { $_.PartitionStyle -eq "RAW" } | Select-Object -First 1
if (-not $rawDisk) {
    Write-Host "No extra data disk attached. Skipping."
    exit 0
}

Write-Host "Initializing data disk (Disk $($rawDisk.Number)) as ${DriveLetter}:..."
Initialize-Disk -Number $rawDisk.Number -PartitionStyle GPT
$partition = New-Partition -DiskNumber $rawDisk.Number -DriveLetter $DriveLetter[0] -UseMaximumSize
Format-Volume -DriveLetter $DriveLetter[0] -FileSystem NTFS -NewFileSystemLabel "SQLData" -Confirm:$false | Out-Null

New-Item -ItemType Directory -Force -Path "${DriveLetter}:\SQLData", "${DriveLetter}:\SQLLogs", "${DriveLetter}:\TempDB" | Out-Null

Write-Host "${DriveLetter}: drive ready ($([math]::Round($partition.Size/1GB,1)) GB)."
