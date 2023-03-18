# Move all of this to HostStart????????

# Ensure license.xml is named correctly. Move to HostStart?
Get-ChildItem C:\CyberArkInstall\License\*.xml | ForEach-Object {Move-Item -Path $_.FullName -Destination "$($_.Directory)\License.xml"}

# Extract install archive
Get-ChildItem C:\CyberArkInstall\ | Where-Object { $_.Name -like 'Server-*' } | ForEach-Object { Expand-Archive -Path $_.FullName -DestinationPath "C:\CyberArkInstall\$($_.BaseName)" }

# Install Vault silently
## This can be done better, probably
$SetupExecutable = Get-ChildItem C:\CyberArkInstall\Server-*\Setup.exe -Recurse
Start-Process -FilePath $SetupExecutable.FullName -ArgumentList '/s', '/f1"C:\CyberArkInstall\silent.iss"', '/f2"C:\CyberArkInstall\VaultSetup.log"'