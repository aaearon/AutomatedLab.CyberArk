# AutomatedLab.CyberArk

Custom CyberArk roles to be used with [AutomatedLab](https://github.com/AutomatedLab/).

## PAMVault

This role can be used to install a CyberArk Vault. Currently it only supports a single Vault setup (no cluster, no DR.) The Administrator and Master passwords are set to `Cyberark1`.

The role will install:

* Microsoft Visual C++ Redistributable for Visual Studio 2015-2022 32b-bit
* Microsoft Visual C++ Redistributable for Visual Studio 2015-2022 64-bit
* Microsoft Framework .NET 4.8 Runtime
* The CyberArk Vault

The role requires the following parameters being passed in it's post installation activity initilization:

* InstallationArchivePath - The full path to the Vault setup archive (Server-v*.zip)
* OperatorKeysFolder - The full path to the folder containing the Operator keys
* MasterKeysFolder - The full path to the folder containing the Master keys
* LicensePath - The full path to the license file

See `PAMVaultExample.ps1` for an example of how to use the role.
