param (
    [Parameter(Mandatory = $true)]
    [string]
    $InstallationArchivePath,

    [Parameter(Mandatory = $true)]
    [string]
    $VaultIpAddress,

    [Parameter(Mandatory = $false)]
    [string]
    $InstallerUsername = 'Administrator',

    [Parameter(Mandatory = $false)]
    [string]
    $InstallerPassword = 'Cyberark1',

    [Parameter(Mandatory = $true)]
    [string]
    $ComputerName
)

Import-Lab $data.Name

Import-Module "$PSScriptRoot\..\PAMCommon\CommonFunctions.psm1" -Force

$InstallationArchiveBaseName = (Get-Item $InstallationArchivePath).BaseName
$LabVmCyberArkInstallFolder = 'C:\CyberArkInstall'

Install-PAMCommonPreRequisites -ComputerName $ComputerName -VisualCRedistributable32 $true -VisualCRedistributable64 $true -DotNetFramework48 $true

# Copy over Pvwa installation files
Copy-LabFileItem -DestinationFolderPath $LabVmCyberArkInstallFolder -Path $InstallationArchivePath -ComputerName $ComputerName
Invoke-LabCommand -ActivityName 'Expand PVWA installation files' -ComputerName $ComputerName -ScriptBlock {
    Set-Location $args[0]
    Expand-Archive -Path "$($args[0])\$($args[1]).zip"
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName

# Update Xml files based on input
Copy-LabFileItem -DestinationFolderPath $LabVmCyberArkInstallFolder -Path "$PSScriptRoot\..\PAMCommon\Set-XmlConfigurationValue.psm1" -ComputerName $ComputerName
Invoke-LabCommand -ActivityName 'Update PVWA configuration files' -ComputerName $ComputerName -ScriptBlock {
    Import-Module "$($args[0])\Set-XmlConfigurationValue.psm1" -Force
    Set-XmlConfigurationValue -Path "$($args[0])\$($args[1])\InstallationAutomation\Registration\PVWARegisterComponentConfig.xml" -Parameter 'vaultip' -Value $args[2]
    Set-XmlConfigurationValue -Path "$($args[0])\$($args[1])\InstallationAutomation\Registration\PVWARegisterComponentConfig.xml" -Parameter 'vaultuser' -Value $args[3]
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName, $VaultIpAddress, $InstallerUsername

# Install Pvwa
Invoke-LabCommand -ActivityName 'PVWA Pre-requisities' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\$($args[1])\InstallationAutomation"
    & .\PVWA_Prerequisites.ps1 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName

Invoke-LabCommand -ActivityName 'PVWA Installation' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\$($args[1])\InstallationAutomation\Installation"
    & .\PVWAInstallation.ps1 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName

Invoke-LabCommand -ActivityName 'PVWA Registration' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\$($args[1])\InstallationAutomation\Registration"
    & .\PVWARegisterComponent.ps1 -pwd $($args[2]) 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName, $InstallerPassword

Invoke-LabCommand -ActivityName 'PVWA Hardening' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\$($args[1])\InstallationAutomation"
    & .\PVWA_Hardening.ps1 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName