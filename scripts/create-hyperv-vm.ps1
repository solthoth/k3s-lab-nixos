param(
    [Parameter(Mandatory)] [string]$VMName,
    [string]$ISOPath = "C:\NixOS\ISOs\nixos-minimal-25.11.10470.0c88e1f2bdb9-x86_64-linux.iso",
    [string]$SwitchName = "K3sLabSwitch",
    [int64]$MemoryGB = 4,
    [int64]$DiskGB = 30,
    [int]$CPUs = 2
)

$VMPath = "C:\NixOS\HyperV\$VMName"
$VHDPath = "$VMPath\$VMName.vhdx"

New-Item -ItemType Directory -Force -Path $VMPath | Out-Null

New-VM -Name $VMName `
       -MemoryStartupBytes ($MemoryGB * 1GB) `
       -Generation 2 `
       -NewVHDPath $VHDPath `
       -NewVHDSizeBytes ($DiskGB * 1GB) `
       -SwitchName $SwitchName `
       -Path $VMPath

Set-VM -Name $VMName -ProcessorCount $CPUs -StaticMemory
Set-VMFirmware -VMName $VMName -EnableSecureBoot Off
Add-VMDvdDrive -VMName $VMName -Path $ISOPath

# Boot from DVD first
$dvd = Get-VMDvdDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -FirstBootDevice $dvd

Start-VM -Name $VMName
Write-Host "VM $VMName started. Connect via Hyper-V Manager to see the console."