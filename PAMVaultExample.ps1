$VaultName = 'PAMVault01'

New-LabDefinition -Name PAMVault -DefaultVirtualizationEngine HyperV -VmPath C:\AutomatedLab-VMs

$PAMVaultRoleProperties = @{
    InstallationArchivePath = 'C:\LabSources\CyberArkInstallFiles\Server-Rls-v13.0.zip'
    OperatorKeysFolder = 'C:\LabSources\CyberArkInstallFiles\DemoOperatorKeys'
    MasterKeysFolder = 'C:\LabSources\CyberArkInstallFiles\DemoMasterKeys'
    LicensePath = 'C:\LabSources\CyberArkInstallFiles\nfr_license.xml'
}
$PAMVaultRole = Get-LabPostInstallationActivity -CustomRole PAMVault -Properties $PAMVaultRoleProperties

# Do everything but the post-installation activities as once that is done for the Vault, WinRM will be unavailable
Install-Lab -BaseImages -NetworkSwitches -VMs -Domains -NoValidation

# Start the Vault VM and wait for it to be ready
Write-ScreenInfo "Starting virtual machines"
Start-LabVM -All -Wait

Checkpoint-LabVM -All -SnapshotName "Pre-install"

# Perform the Vault installation. The hardening part of the installation will kill the ability to use WinRM so it will timeout and throw an error. We want to ignore that error.
Invoke-LabCommand -ComputerName $VaultName -PostInstallationActivity -ActivityName 'CyberArk Vault installation' -ErrorAction SilentlyContinue

