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

$LabVmCyberArkInstallFolder = 'C:\CyberArkInstall'

Import-Lab -Name $data.Name

$CyberArkInstallFolder = New-Item -ItemType Directory -Path (Join-Path -Path $LabSources -ChildPath 'CyberArkInstall') -Force

#  Microsoft Visual C++ Redistributable for Visual Studio 2015-2022 32-bit and 64-bit versions
$VisualCRedistX86 = Get-LabInternetFile -Uri 'https://aka.ms/vs/17/release/vc_redist.x86.exe' -Path $CyberArkInstallFolder -PassThru
Install-LabSoftwarePackage -ComputerName $ComputerName -Path $VisualCRedistX86.FullName -CommandLine '/Q'

$VisualCRedistX64 = Get-LabInternetFile -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -Path $CyberArkInstallFolder -PassThru
Install-LabSoftwarePackage -ComputerName $ComputerName -Path $VisualCRedistX64.FullName -CommandLine '/Q'

# Microsoft Framework .NET 4.8 Runtime
$DotNetFramework48 = Get-LabInternetFile -Uri 'https://go.microsoft.com/fwlink/?linkid=2088631' -Path $CyberArkInstallFolder -PassThru
Install-LabSoftwarePackage -ComputerName $ComputerName -Path $DotNetFramework48.FullName -CommandLine '/install /quiet'

Write-ScreenInfo 'Waiting for restart to complete before continuing installation'
Wait-LabVMRestart -ComputerName $ComputerName

# Copy over Pvwa installation files
Copy-LabFileItem -DestinationFolderPath $LabVmCyberArkInstallFolder -Path $InstallationArchivePath -ComputerName $ComputerName
Invoke-LabCommand -ActivityName 'Expand PVWA installation files' -ComputerName $ComputerName -ScriptBlock {
    $ServerArchive = Get-ChildItem $args | Where-Object { $_.Name -like 'Password Vault Web Access-Rls-*.zip' }
    Expand-Archive -Path $ServerArchive.FullName -DestinationPath "$args\$($ServerArchive.BaseName)"
} -ArgumentList $LabVmCyberArkInstallFolder

# Update Xml files based on input
Copy-LabFileItem -DestinationFolderPath $LabVmCyberArkInstallFolder -Path "$PSScriptRoot\..\PAMCommon\Set-XmlConfigurationValue.psm1" -ComputerName $ComputerName
Invoke-LabCommand -ActivityName 'Update PVWA configuration files' -ComputerName $ComputerName -ScriptBlock {
    Import-Module "$($args[0])\Set-XmlConfigurationValue.psm1" -Force
    Set-XmlConfigurationValue -Path "$($args[0])\Password Vault Web Access-Rls-v13.0\InstallationAutomation\Registration\PVWARegisterComponentConfig.xml" -Parameter 'vaultip' -Value $args[1]
    Set-XmlConfigurationValue -Path "$($args[0])\Password Vault Web Access-Rls-v13.0\InstallationAutomation\Registration\PVWARegisterComponentConfig.xml" -Parameter 'vaultuser' -Value $args[2]
} -ArgumentList $LabVmCyberArkInstallFolder, $VaultIpAddress, $InstallerUsername

# Install Pvwa
Invoke-LabCommand -ActivityName 'PVWA Pre-requisities' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\Password Vault Web Access-Rls-v13.0\InstallationAutomation"
    & .\PVWA_Prerequisites.ps1 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder

Invoke-LabCommand -ActivityName 'PVWA Installation' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\Password Vault Web Access-Rls-v13.0\InstallationAutomation\Installation"
    & .\PVWAInstallation.ps1 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder

Invoke-LabCommand -ActivityName 'PVWA Registration' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\Password Vault Web Access-Rls-v13.0\InstallationAutomation\Registration"
    & .\PVWARegisterComponent.ps1 -pwd $($args[1]) 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallerPassword

Invoke-LabCommand -ActivityName 'PVWA Hardening' -ComputerName $ComputerName -ScriptBlock {
    Set-Location "$($args[0])\Password Vault Web Access-Rls-v13.0\InstallationAutomation"
    & .\PVWA_Hardening.ps1 6> $null
} -ArgumentList $LabVmCyberArkInstallFolder