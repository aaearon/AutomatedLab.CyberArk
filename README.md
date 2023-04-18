# AutomatedLab.CyberArk

Custom CyberArk roles to be used with [AutomatedLab](https://github.com/AutomatedLab/).

Copy all folders starting with `PAM` to `$LabSources\CustomRoles`. See `PAMVaultExample.ps1` for an example of how to use the roles.

## PAMVault

This role can be used to install a CyberArk Vault. Currently it only supports a single Vault setup (no cluster, no DR.) The Administrator and Master passwords are set to `Cyberark1`.

The role will install:

* Microsoft Visual C++ Redistributable for Visual Studio 2015-2022 32-bit
* Microsoft Visual C++ Redistributable for Visual Studio 2015-2022 64-bit
* Microsoft Framework .NET 4.8 Runtime
* The CyberArk Vault

The role requires the following parameters being passed in it's post installation activity initilization:

* InstallationArchivePath - The full path to the Vault setup archive (`Server-v*.zip`)
* OperatorKeysFolder - The full path to the folder containing the Operator keys
* MasterKeysFolder - The full path to the folder containing the Master keys
* LicensePath - The full path to the license file

## PAMPvwa

This role can be used to install a CyberArk Password Vault Web Access. The user and password for the installation as well as the Vault IP can be customized.

The role will install:

* Microsoft Visual C++ Redistributable for Visual Studio 2015-2022 32-bit
* Microsoft Visual C++ Redistributable for Visual Studio 2015-2022 64-bit
* Microsoft Framework .NET 4.8 Runtime
* The CyberArk PVWA

The role requires the following parameters being passed in it's post installation activity initilization:

* InstallationArchivePath - The full path to the Vault setup archive (`Password Vault Web Access-Rls-*.zip`)
* VaultIpAddress - The IP address of the Vault.
* (optional) InstallerUsername - The name of the user to register the PVWA with.
* (optional) InstallerPassword - The password for the user to register the PVWA with.

## PAMCpm

This role can be used to install a CyberArk Central Policy Manager. The user and password for the installation as well as the Vault IP can be customized. This role can be installed on the same machine as one with the PAMPvwa role.

The role will install:

* Microsoft Framework .NET 4.8 Runtime
* The CyberArk Central Policy Manager

The role requires the following parameters being passed in it's post installation activity initilization:

* InstallationArchivePath - The full path to the Vault setup archive (`Central Policy Manager-Rls-*.zip`)
* VaultIpAddress - The IP address of the Vault.
* (optional) InstallerUsername - The name of the user to register the CPM with.
* (optional) InstallerPassword - The password for the user to register the CPM with.

## PAMPsm

This role can be used to install a CyberArk Privileged Session Manager. The user and password for the installation as well as the Vault IP can be customized. This role is meant to be installed on it's own machine.

The role will install:

* Microsoft Framework .NET 4.8 Runtime
* The CyberArk Privileged Session Manager

The role requires the following parameters being passed in it's post installation activity initilization:

* InstallationArchivePath - The full path to the Vault setup archive (`Privileged Session Manager-Rls-*.zip`)
* VaultIpAddress - The IP address of the Vault.
* (optional) InstallerUsername - The name of the user to register the PSM with.
* (optional) InstallerPassword - The password for the user to register the PSM with.
