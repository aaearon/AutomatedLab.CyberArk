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
Invoke-LabCommand -ActivityName 'Expand PSM installation files' -ComputerName $ComputerName -ScriptBlock {
    Set-Location $args[0]
    Expand-Archive -Path "$($args[0])\$($args[1]).zip"
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName

Copy-LabFileItem -DestinationFolderPath $LabVmCyberArkInstallFolder -Path "$PSScriptRoot\..\PAMCommon\Set-XmlConfigurationValue.psm1" -ComputerName $ComputerName
Invoke-LabCommand -ActivityName 'Update PSM configuration files' -ComputerName $ComputerName -ScriptBlock {
    Import-Module "$($args[0])\Set-XmlConfigurationValue.psm1" -Force
    Set-XmlConfigurationValue -Path "$($args[0])\$($args[1])\InstallationAutomation\Registration\RegistrationConfig.xml" -Parameter 'vaultip' -Value $args[2]
    Set-XmlConfigurationValue -Path "$($args[0])\$($args[1])\InstallationAutomation\Registration\RegistrationConfig.xml" -Parameter 'vaultusername' -Value $args[3]
    Set-XmlConfigurationValue -Path "$($args[0])\$($args[1])\InstallationAutomation\Registration\RegistrationConfig.xml" -Parameter 'accepteula' -Value 'yes'
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName, $VaultIpAddress, $InstallerUsername

Invoke-LabCommand -ActivityName 'PSM Readiness' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\$($args[1])\InstallationAutomation"
    & .\Execute-Stage.ps1 "$($args[0])\$($args[1])\InstallationAutomation\Readiness\ReadinessConfig.xml" silent 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName

Invoke-LabCommand -ActivityName 'PSM Prerequisities' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\$($args[1])\InstallationAutomation"
    & .\Execute-Stage.ps1 "$($args[0])\$($args[1])\InstallationAutomation\Prerequisites\PrerequisitesConfig.xml" silent 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName -ErrorAction SilentlyContinue

# We have the installation silently continue as sometimes the installation CAN (but not always) result in a restart. The AutomatedLab gracefully handles this.
Invoke-LabCommand -ActivityName 'PSM Install' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\$($args[1])\InstallationAutomation"
    & .\Execute-Stage.ps1 "$($args[0])\$($args[1])\InstallationAutomation\Installation\InstallationConfig.xml" silent 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName -ErrorAction SilentlyContinue

Invoke-LabCommand -ActivityName 'PSM Postinstallation' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\$($args[1])\InstallationAutomation"
    & .\Execute-Stage.ps1 "$($args[0])\$($args[1])\InstallationAutomation\PostInstallation\PostInstallationConfig.xml" 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName

Invoke-LabCommand -ActivityName 'PSM Hardening' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\$($args[1])\InstallationAutomation"
    & .\Execute-Stage.ps1 "$($args[0])\$($args[1])\InstallationAutomation\Hardening\HardeningConfig.xml" 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName -ErrorAction SilentlyContinue

# SilentlyContinue as registration will throw an error if it cannot connect to the CyberArk API gateway due to untrusted cert
Invoke-LabCommand -ActivityName 'PSM Registration' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\$($args[1])\InstallationAutomation"
    & .\Execute-Stage.ps1 "$($args[0])\$($args[1])\InstallationAutomation\Registration\RegistrationConfig.xml" -pwd $($args[2]) 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName, $InstallerPassword -ErrorAction SilentlyContinue
