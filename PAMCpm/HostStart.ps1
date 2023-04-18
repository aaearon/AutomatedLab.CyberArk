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

Import-Module "$PSScriptRoot\..\PAMCommon\CommonFunctions.psm1" -Force

$InstallationArchiveBaseName = (Get-Item $InstallationArchivePath).BaseName
$LabVmCyberArkInstallFolder = 'C:\CyberArkInstall'

Install-PAMCommonPreRequisites -ComputerName $ComputerName -DotNetFramework48 $true

Copy-LabFileItem -DestinationFolderPath $LabVmCyberArkInstallFolder -Path $InstallationArchivePath -ComputerName $ComputerName
Invoke-LabCommand -ActivityName 'Expand CPM installation files' -ComputerName $ComputerName -ScriptBlock {
    Set-Location $args[0]
    Expand-Archive -Path "$($args[0])\$($args[1]).zip"
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName

Copy-LabFileItem -DestinationFolderPath $LabVmCyberArkInstallFolder -Path "$PSScriptRoot\..\PAMCommon\Set-XmlConfigurationValue.psm1" -ComputerName $ComputerName
Invoke-LabCommand -ActivityName 'Update CPM configuration files' -ComputerName $ComputerName -ScriptBlock {
    Import-Module "$($args[0])\Set-XmlConfigurationValue.psm1" -Force
    Set-XmlConfigurationValue -Path "$($args[0])\$($args[1])\InstallationAutomation\Registration\CPMRegisterComponentConfig.xml" -Parameter 'vaultip' -Value $args[2]
    Set-XmlConfigurationValue -Path "$($args[0])\$($args[1])\InstallationAutomation\Registration\CPMRegisterComponentConfig.xml" -Parameter 'vaultUser' -Value $args[3]
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName, $VaultIpAddress, $InstallerUsername

Invoke-LabCommand -ActivityName 'CPM PreInstallation' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\$($args[1])\InstallationAutomation"
    Write-Output A | powershell "& .\CPM_PreInstallation.ps1" 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName

# We have the installation silently continue as sometimes the installation CAN (but not always) result in a restart. The AutomatedLab gracefully handles this.
Invoke-LabCommand -ActivityName 'CPM Install' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\$($args[1])\InstallationAutomation\Installation"
    & .\CPMInstallation.ps1 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName -ErrorAction SilentlyContinue

Invoke-LabCommand -ActivityName 'CPM Registration' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\$($args[1])\InstallationAutomation\Registration"
    & .\CPMRegisterCommponent.ps1 -pwd $($args[2]) 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName, $InstallerPassword

# Silently continue the hardening as it will 'fail' when the CPM Scanner service attempts to start but cannot as the PVWA has an untrusted certificate.
Invoke-LabCommand -ActivityName 'CPM Hardening' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\$($args[1])\InstallationAutomation"
    & .\CPM_Hardening.ps1 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName -ErrorAction SilentlyContinue