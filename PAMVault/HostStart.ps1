param (
    [Parameter(Mandatory = $true)]
    [string]
    $InstallationArchivePath,

    [Parameter(Mandatory = $true)]
    [string]
    $OperatorKeysFolder,

    [Parameter(Mandatory = $true)]
    [string]
    $MasterKeysFolder,

    # [Parameter(Mandatory = $true)]
    # [string]
    # $MasterPassword,

    # [Parameter(Mandatory = $true)]
    # [string]
    # $AdministratorPassword,

    [Parameter(Mandatory = $true)]
    [string]
    $LicensePath,

    [Parameter(Mandatory = $false)]
    [string]
    $Name = 'Windows User',

    [Parameter(Mandatory = $false)]
    [string]
    $Company = 'Company',

    [Parameter(Mandatory = $false)]
    [string]
    $InstallationFolder = 'C:\Program Files (x86)\PrivateArk',

    [Parameter(Mandatory = $false)]
    [string]
    $SafesFolder = 'C:\PrivateArk\Safes',

    [Parameter(Mandatory)]
    [string]$ComputerName
)

Import-Module "$PSScriptRoot\..\PAM.Common\CommonFunctions.psm1" -Force

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

Wait-LabVMRestart -ComputerName $ComputerName

# License and keys
$LabVmKeysFolder = 'C:\CyberArkKeys'
Copy-LabFileItem -DestinationFolder $LabVmKeysFolder -Path $OperatorKeysFolder -ComputerName $ComputerName
Copy-LabFileItem -DestinationFolder $LabVmKeysFolder -Path $MasterKeysFolder -ComputerName $ComputerName
Copy-LabFileItem -DestinationFolder "$LabVmCyberArkInstallFolder\License" -Path $LicensePath -ComputerName $ComputerName
Invoke-LabCommand -ActivityName 'Ensure correct name for License.xml' -ComputerName $ComputerName -ScriptBlock {
    Get-ChildItem "$($args[0])\License\*.xml" | ForEach-Object { Move-Item -Path $_.FullName -Destination "$($_.Directory)\License.xml" }
} -ArgumentList $LabVmCyberArkInstallFolder

# Copy over Vault installation files
Copy-LabFileItem -DestinationFolderPath $LabVmCyberArkInstallFolder -Path $InstallationArchivePath -ComputerName $ComputerName
Invoke-LabCommand -ActivityName 'Expand Vault installation files' -ComputerName $ComputerName -ScriptBlock {
    $ServerArchive = Get-ChildItem $args | Where-Object { $_.Name -like 'Server-*.zip' }
    Expand-Archive -Path $ServerArchive.FullName -DestinationPath "$args\$($ServerArchive.BaseName)"
} -ArgumentList $LabVmCyberArkInstallFolder

# Scheduled Task for Windows Firewall workaround
Copy-LabFileItem -DestinationFolderPath $LabVmCyberArkInstallFolder -Path "$PSScriptRoot\FirewallWorkaround.reg" -ComputerName $ComputerName
Invoke-LabCommand -ActivityName 'Set up Windows Firewall workaround scheduled task for post-installation reboot' -ComputerName $ComputerName -ScriptBlock {
    $TaskName = 'FirewallWorkaround'
    # This scheduled task needs to run only after hardening completes (after the reboot of the Vault installation) but the Vault must restart after the keys are imported for it to take effect.
    # We import then disable the task so it doesn't run again as we'd be stuck in a reboot loop.
    $TaskAction = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument "-NoProfile -WindowStyle Hidden -Command % {regedit.exe /s `"$($args[0])\FirewallWorkaround.reg`";Disable-ScheduledTask -TaskName $($TaskName);Restart-Computer}"
    $TaskTrigger = New-ScheduledTaskTrigger -AtStartup

    Register-ScheduledTask -TaskName $TaskName -Action $TaskAction -Trigger $TaskTrigger -User SYSTEM
} -ArgumentList $LabVmCyberArkInstallFolder

# Copy silent install file
Copy-LabFileItem -DestinationFolderPath $LabVmCyberArkInstallFolder -Path "$PSScriptRoot\silent.iss" -ComputerName $ComputerName

# Install Vault
Install-LabSoftwarePackage -ComputerName $ComputerName -LocalPath $LabVmCyberArkInstallFolder\Server-Rls-v13.0\Setup.exe -CommandLine "/s /f1`"$LabVmCyberArkInstallFolder\silent.iss`" /f2`"$LabVmCyberArkInstallFolder\VaultSetup.log`""
