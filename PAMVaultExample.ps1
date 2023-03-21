$VaultName = 'PAMVault'

New-LabDefinition -Name PAMVault -DefaultVirtualizationEngine HyperV -VmPath C:\AutomatedLab-VMs

$PAMVaultRoleProperties = @{
    InstallationArchivePath = 'C:\LabSources\CyberArkInstallFiles\Server-Rls-v13.0.zip'
    OperatorKeysFolder = 'C:\LabSources\CyberArkInstallFiles\DemoOperatorKeys'
    MasterKeysFolder = 'C:\LabSources\CyberArkInstallFiles\DemoMasterKeys'
    LicensePath = 'C:\LabSources\CyberArkInstallFiles\nfr_license.xml'
}
$PAMVaultRole = Get-LabPostInstallationActivity -CustomRole PAMVault -Properties $PAMVaultRoleProperties

Add-LabMachineDefinition -Name $VaultName -PostInstallationActivity $PAMVaultRole -Memory 4GB -Processors 1

# Do everything but the post-installation activities as once that is done for the Vault, WinRM will be unavailable
Install-Lab -BaseImages -NetworkSwitches -VMs -Domains -NoValidation

# Start the Vault VM and wait for it to be ready
Write-ScreenInfo "Starting $VaultName."
Start-LabVM $VaultName -Wait

# Perform the Vault installation
Invoke-LabCommand -ComputerName $VaultName -PostInstallationActivity -ActivityName 'CyberArk Vault installation'