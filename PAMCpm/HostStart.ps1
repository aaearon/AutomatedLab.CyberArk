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

$LabVmCyberArkInstallFolder = 'C:\CyberArkInstall'

Import-Lab -Name $data.Name

Install-PAMCommonPreRequisites -ComputerName $ComputerName -DotNetFramework48 $true

Copy-LabFileItem -DestinationFolderPath $LabVmCyberArkInstallFolder -Path $InstallationArchivePath -ComputerName $ComputerName
Invoke-LabCommand -ActivityName 'Expand CPM installation files' -ComputerName $ComputerName -ScriptBlock {
    $ServerArchive = Get-ChildItem $args | Where-Object { $_.Name -like 'Central Policy Manager-Rls-*.zip' }
    Expand-Archive -Path $ServerArchive.FullName -DestinationPath "$args\$($ServerArchive.BaseName)"
} -ArgumentList $LabVmCyberArkInstallFolder

Copy-LabFileItem -DestinationFolderPath $LabVmCyberArkInstallFolder -Path "$PSScriptRoot\..\PAMCommon\Set-XmlConfigurationValue.psm1" -ComputerName $ComputerName
Invoke-LabCommand -ActivityName 'Update CPM configuration files' -ComputerName $ComputerName -ScriptBlock {
    Import-Module "$($args[0])\Set-XmlConfigurationValue.psm1" -Force
    Set-XmlConfigurationValue -Path "$($args[0])\Central Policy Manager-Rls-v13.0\InstallationAutomation\Registration\CPMRegisterComponentConfig.xml" -Parameter 'vaultip' -Value $args[1]
    Set-XmlConfigurationValue -Path "$($args[0])\Central Policy Manager-Rls-v13.0\InstallationAutomation\Registration\CPMRegisterComponentConfig.xml" -Parameter 'vaultUser' -Value $args[2]
} -ArgumentList $LabVmCyberArkInstallFolder, $VaultIpAddress, $InstallerUsername

Invoke-LabCommand -ActivityName 'CPM Pre-requisities' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\Central Policy Manager-Rls-v13.0\InstallationAutomation"
    & .\CPM_PreInstallation.ps1 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder

Invoke-LabCommand -ActivityName 'CPM Install' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\Central Policy Manager-Rls-v13.0\InstallationAutomation\Installation"
    & .\CPMInstallation.ps1 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder

Invoke-LabCommand -ActivityName 'CPM Registration' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\Central Policy Manager-Rls-v13.0\InstallationAutomation\Registration"
    & .\CPMRegisterCommponent.ps1 -pwd $($args[1]) 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallerPassword

Invoke-LabCommand -ActivityName 'CPM Hardening' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\Central Policy Manager-Rls-v13.0\InstallationAutomation"
    & .\CPM_Hardening.ps1 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder