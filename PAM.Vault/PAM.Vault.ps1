$LabVmCyberArkInstallFolder = 'C:\CyberArkInstall'

# Move all of this to HostStart???????? This can be an Invoke-LabCommand but not Install-LabSoftwarePackage as  WinRM will be disabled as part of Hardening
$SetupExecutable = Get-ChildItem $LabVmCyberArkInstallFolder\Server-*\Setup.exe -Recurse
Start-Process -FilePath $SetupExecutable.FullName -ArgumentList '/s', "/f1`"$LabVmCyberArkInstallFolder\silent.iss`"", "/f2`"$LabVmCyberArkInstallFolder\VaultSetup.log`""