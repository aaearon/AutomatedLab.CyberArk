
New-LabDefinition -Name PAM -DefaultVirtualizationEngine HyperV -VmPath C:\AutomatedLab-VMs

Add-LabVirtualNetworkDefinition -Name PAM -AddressSpace 192.168.0.0/24

$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:OperatingSystem'      = 'Windows Server 2019 Datacenter Evaluation (Desktop Experience)'
    'Add-LabMachineDefinition:Memory'               = 4GB
    'Add-LabMachineDefinition:Network'              = 'PAM'
}

$DC01MachineProperties = @{
    Name = 'DC01'
    Roles = 'RootDC'
    DomainName = 'acme.corp'
}

Add-LabMachineDefinition @DC01MachineProperties

$PAMVaultRoleProperties = @{
    InstallationArchivePath = 'C:\LabSources\CyberArkInstallFiles\Server-Rls-v13.0.zip'
    OperatorKeysFolder      = 'C:\LabSources\CyberArkInstallFiles\DemoOperatorKeys'
    MasterKeysFolder        = 'C:\LabSources\CyberArkInstallFiles\DemoMasterKeys'
    LicensePath             = 'C:\LabSources\CyberArkInstallFiles\nfr_license.xml'
}
$PAMVaultRole = Get-LabPostInstallationActivity -CustomRole PAMVault -Properties $PAMVaultRoleProperties

$PAMVaultMachineProperties = @{
    Name = 'VAULT01'
    IpAddress = '192.168.0.100'
    PostInstallationActivity = $PAMVaultRole
}

Add-LabMachineDefinition @PAMVaultMachineProperties

$PAMPvwaRoleProperties = @{
    InstallationArchivePath = 'C:\LabSources\CyberArkInstallFiles\Password Vault Web Access-Rls-v13.0.zip'
    VaultIpAddress          = '192.168.0.100'
}
$PAMPvwaRole = Get-LabPostInstallationActivity -CustomRole PAMPvwa -Properties $PAMPvwaRoleProperties

$PAMCpmRoleProperties = @{
    InstallationArchivePath = 'C:\LabSources\CyberArkInstallFiles\Central Policy Manager-Rls-v13.0.zip'
    VaultIpAddress          = '192.168.0.100'
}
$PAMCpmRole = Get-LabPostInstallationActivity -CustomRole PAMCpm -Properties $PAMCpmRoleProperties

$COMP01MachineParameters = @{
    Name = 'COMP01'
    DomainName = 'acme.corp'
    PostInstallationActivity = $PAMPvwaRole,$PAMCpmRole
}

Add-LabMachineDefinition @COMP01MachineParameters

$PAMPsmRoleProperties = @{
    InstallationArchivePath = 'C:\LabSources\CyberArkInstallFiles\Privileged Session Manager-Rls-v13.0.1.zip'
    VaultIpAddress          = '192.168.0.100'
}
$PAMPsmRole = Get-LabPostInstallationActivity -CustomRole PAMPsm -Properties $PAMPsmRoleProperties

$PSM01MachineParameters = @{
    Name = 'PSM01'
    DomainName = 'acme.corp'
    PostInstallationActivity = $PAMPsmRole
}

Add-LabMachineDefinition @PSM01MachineParameters

# Do everything but the post-installation activities as once that is done for the Vault, WinRM will be unavailable
Install-Lab -BaseImages -NetworkSwitches -VMs -Domains -NoValidation

# Perform the Vault installation. The hardening part of the installation will kill the ability to use WinRM so it will timeout and throw an error. We want to ignore that error.
Invoke-LabCommand -ComputerName VAULT01 -PostInstallationActivity -ActivityName 'CyberArk Vault installation' -ErrorAction SilentlyContinue
Invoke-LabCommand -ComputerName COMP01 -PostInstallationActivity -ActivityName 'CyberArk Pvwa and CPM installation'
Invoke-LabCommand -ComputerName PSM01 -PostInstallationActivity -ActivityName 'CyberArk PSM installation'
