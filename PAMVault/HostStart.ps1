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

Import-Module "$PSScriptRoot\..\PAMCommon\CommonFunctions.psm1" -Force
$InstallationArchiveBaseName = (Get-Item $InstallationArchivePath).BaseName

$LabVmCyberArkInstallFolder = 'C:\CyberArkInstall'

Install-PAMCommonPreRequisites -ComputerName $ComputerName -VisualCRedistributable32 $true -VisualCRedistributable64 $true -DotNetFramework48 $true

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
    Set-Location $args[0]
    Expand-Archive -Path "$($args[0])\$($args[1]).zip"
} -ArgumentList $LabVmCyberArkInstallFolder, $InstallationArchiveBaseName

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
Install-LabSoftwarePackage -ComputerName $ComputerName -LocalPath "$LabVmCyberArkInstallFolder\$InstallationArchiveBaseName\Setup.exe" -CommandLine "/s /f1`"$LabVmCyberArkInstallFolder\silent.iss`" /f2`"$LabVmCyberArkInstallFolder\VaultSetup.log`""

# The below is simply not reliable (TNC seems to get stuck)
# Write-ScreenInfo "Waiting for Vault installation to be complete and accessible on port 1858."
# Wait-VaultConnectivity -ComputerName $ComputerName
# Write-ScreenInfo "Vault is accessible on port 1858! Done."