$VaultName = 'VAULT01'
$VaultIpAddress = '192.168.11.3'
$PvwaName = 'COMP01'
$CpmName = $PvwaName

New-LabDefinition -Name PAMVault -DefaultVirtualizationEngine HyperV -VmPath C:\AutomatedLab-VMs

$PAMVaultRoleProperties = @{
    InstallationArchivePath = 'C:\LabSources\CyberArkInstallFiles\Server-Rls-v13.0.zip'
    OperatorKeysFolder      = 'C:\LabSources\CyberArkInstallFiles\DemoOperatorKeys'
    MasterKeysFolder        = 'C:\LabSources\CyberArkInstallFiles\DemoMasterKeys'
    LicensePath             = 'C:\LabSources\CyberArkInstallFiles\nfr_license.xml'
}
$PAMVaultRole = Get-LabPostInstallationActivity -CustomRole PAMVault -Properties $PAMVaultRoleProperties

Add-LabMachineDefinition -Name $VaultName -PostInstallationActivity $PAMVaultRole -OperatingSystem 'Windows Server 2019 Datacenter Evaluation (Desktop Experience)' -IpAddress $VaultIpAddress

$PAMPvwaRoleProperties = @{
    InstallationArchivePath = 'C:\LabSources\CyberArkInstallFiles\Password Vault Web Access-Rls-v13.0.zip'
    VaultIpAddress          = $VaultIpAddress
}
$PAMPvwaRole = Get-LabPostInstallationActivity -CustomRole PAMPvwa -Properties $PAMPvwaRoleProperties

$PAMCpmRoleProperties = @{
    InstallationArchivePath = 'C:\LabSources\CyberArkInstallFiles\Central Policy Manager-Rls-v13.0.zip'
    VaultIpAddress          = $VaultIpAddress
}
$PAMCpmRole = Get-LabPostInstallationActivity -CustomRole PAMCpm -Properties $PAMCpmRoleProperties

Add-LabMachineDefinition -Name $PvwaName -PostInstallationActivity $PAMPvwaRole,$PAMCpmRole -OperatingSystem 'Windows Server 2019 Datacenter Evaluation (Desktop Experience)'

# Do everything but the post-installation activities as once that is done for the Vault, WinRM will be unavailable
Install-Lab -BaseImages -NetworkSwitches -VMs -Domains -NoValidation

# Start the Vault VM and wait for it to be ready
Write-ScreenInfo 'Starting virtual machines'
Start-LabVM -All

# By the time the Vault starts and installs, the other VMs will be ready
Wait-LabVM -ComputerName $VaultName

# Perform the Vault installation. The hardening part of the installation will kill the ability to use WinRM so it will timeout and throw an error. We want to ignore that error.
Invoke-LabCommand -ComputerName $VaultName -PostInstallationActivity -ActivityName 'CyberArk Vault installation' -ErrorAction SilentlyContinue

Invoke-LabCommand -ComputerName $PvwaName -PostInstallationActivity -ActivityName 'CyberArk Pvwa and CPM installation'
