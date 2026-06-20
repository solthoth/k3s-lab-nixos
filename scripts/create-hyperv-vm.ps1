param(
    [Parameter(Mandatory)] [string]$VMName,
    [string]$ISOPath = "C:\NixOS\ISOs\nixos-minimal-25.11.10470.0c88e1f2bdb9-x86_64-linux.iso",
    [string]$SwitchName = "K3sLabSwitch",
    [int64]$MemoryGB = 8,
    [int64]$DiskGB = 60,
    [int]$CPUs = 4
)

function Write-Log {
    param([string]$Level, [string]$Message)
    $ts = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "INFO"  { "Cyan" }
        "OK"    { "Green" }
        "WARN"  { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    Write-Host "[$ts] [$Level] $Message" -ForegroundColor $color
}

$VMPath  = "C:\NixOS\HyperV\$VMName"
$VHDPath = "$VMPath\$VMName.vhdx"

Write-Log INFO "Starting VM provisioning for '$VMName'"
Write-Log INFO "  Switch : $SwitchName"
Write-Log INFO "  Memory : ${MemoryGB} GB"
Write-Log INFO "  Disk   : ${DiskGB} GB"
Write-Log INFO "  CPUs   : $CPUs"
Write-Log INFO "  ISO    : $ISOPath"

# --- Directory ---
if (Test-Path $VMPath) {
    Write-Log WARN "VM directory already exists: $VMPath"
} else {
    New-Item -ItemType Directory -Force -Path $VMPath | Out-Null
    Write-Log OK "Created VM directory: $VMPath"
}

# --- VM ---
$existingVM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
if ($existingVM) {
    Write-Log WARN "VM '$VMName' already exists (State: $($existingVM.State)) — skipping creation"
} else {
    Write-Log INFO "Creating VM '$VMName'..."
    New-VM -Name $VMName `
           -MemoryStartupBytes ($MemoryGB * 1GB) `
           -Generation 2 `
           -NewVHDPath $VHDPath `
           -NewVHDSizeBytes ($DiskGB * 1GB) `
           -SwitchName $SwitchName `
           -Path $VMPath | Out-Null
    Write-Log OK "VM created"

    Set-VM -Name $VMName -ProcessorCount $CPUs -StaticMemory
    Write-Log OK "Processor count set to $CPUs (static memory)"

    Set-VMFirmware -VMName $VMName -EnableSecureBoot Off
    Write-Log OK "Secure Boot disabled"
}

# --- DVD drive ---
$existingDvd = Get-VMDvdDrive -VMName $VMName -ErrorAction SilentlyContinue |
               Where-Object { $_.Path -eq $ISOPath }
if ($existingDvd) {
    Write-Log WARN "DVD drive with ISO '$ISOPath' already attached — skipping"
} else {
    Write-Log INFO "Attaching ISO: $ISOPath"
    Add-VMDvdDrive -VMName $VMName -Path $ISOPath
    Write-Log OK "DVD drive attached"
}

# --- Boot order ---
$dvd = Get-VMDvdDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -FirstBootDevice $dvd
Write-Log OK "Boot order set: DVD first"

# --- Start ---
$vm = Get-VM -Name $VMName
if ($vm.State -eq "Running") {
    Write-Log WARN "VM '$VMName' is already running — skipping start"
} else {
    Write-Log INFO "Starting VM '$VMName'..."
    Start-VM -Name $VMName
    Write-Log OK "VM started"
}

Write-Log OK "Done. Connect via Hyper-V Manager to see the console."
