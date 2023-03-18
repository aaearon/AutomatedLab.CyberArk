param (
    [Parameter(Mandatory = $true)]
    [string]
    $CyberArkPamInstallPackagePath,

    [Parameter(Mandatory = $true)]
    [string]
    $OperatorKeysFolder,

    [Parameter(Mandatory = $true)]
    [string]
    $MasterKeysFolder,

    [Parameter(Mandatory = $true)]
    [string]
    $MasterPassword,

    [Parameter(Mandatory = $true)]
    [string]
    $AdministratorPassword,

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

$LabVmCyberArkInstallFolder = 'C:\CyberArkInstall'

Import-Lab -Name $data.Name

$CyberArkInstallFolder = New-Item -ItemType Directory -Path (Join-Path -Path $LabSources -ChildPath 'CyberArkInstall') -Force

#  Microsoft Visual C++ Redistributable for Visual Studio 2015-2022 32-bit and 64-bit versions
$VisualCRedistX86 = Get-LabInternetFile -Uri 'https://aka.ms/vs/17/release/vc_redist.x86.exe' -Path $CyberArkInstallFolder -PassThru
Install-LabSoftwarePackage -ComputerName $ComputerName -Path $VisualCRedistX86.FullName -CommandLine '/Q /norestart'

$VisualCRedistX64 = Get-LabInternetFile -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -Path $CyberArkInstallFolder -PassThru
Install-LabSoftwarePackage -ComputerName $ComputerName -Path $VisualCRedistX64.FullName -CommandLine '/Q /norestart'

# Microsoft Framework .NET 4.8 Runtime
$DotNetFramework48 = Get-LabInternetFile -Uri 'https://go.microsoft.com/fwlink/?linkid=2088631' -Path $CyberArkInstallFolder -PassThru
Install-LabSoftwarePackage -ComputerName $ComputerName -Path $DotNetFramework48.FullName -CommandLine '/install /quiet'

# License and keys
$LabVmKeysFolder = 'C:\CyberArkKeys'
Copy-LabFileItem -DestinationFolder $LabVmKeysFolder -Path $OperatorKeysFolder -ComputerName $ComputerName
Copy-LabFileItem -DestinationFolder $LabVmKeysFolder -Path $MasterKeysFolder -ComputerName $ComputerName
Copy-LabFileItem -DestinationFolder "$LabVmCyberArkInstallFolder\License" -Path $LicensePath -ComputerName $ComputerName
Invoke-LabCommand -ActivityName 'Ensure correct name for License.xml' -ComputerName $ComputerName -ScriptBlock {
    Get-ChildItem "$($args[0])\License\*.xml" | ForEach-Object { Move-Item -Path $_.FullName -Destination "$($_.Directory)\License.xml" }
} -ArgumentList $LabVmCyberArkInstallFolder

# Copy over Vault installation files
$LocalFilesFolder = New-Item -ItemType Directory -Path (Join-Path -Path $CyberArkInstallFolder -ChildPath 'Vault') -Force
ExpandFrom-Archive -Path $CyberArkPamInstallPackagePath -OutPath $LocalFilesFolder.FullName -Filter '*Vault*'
Copy-LabFileItem -DestinationFolderPath $LabVmCyberArkInstallFolder -Path "$($VaultFilesFolder.FullName)\*" -ComputerName $ComputerName
Invoke-LabCommand -ActivityName 'Expand Vault installation files' -ComputerName $ComputerName -ScriptBlock {
    $ServerArchive = Get-ChildItem $args | Where-Object { $_.Name -like 'Server-*' }
    Expand-Archive -Path $ServerArchive.FullName -DestinationPath "$args\$($ServerArchive.BaseName)"
} -ArgumentList $LabVmCyberArkInstallFolder

# Copy silent install file
Copy-LabFileItem -DestinationFolderPath $LabVmCyberArkInstallFolder -Path 'silent.iss' -ComputerName $ComputerName

function ExpandFrom-Archive {
    param (
        $Path,
        $OutPath,
        $Filter
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $Archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    $Archive.Entries |
    Where-Object { $_.FullName -like $Filter } |
    ForEach-Object {
        $FileName = $_.Name
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, "$OutPath\$FileName", $true)
    }

    $Archive.Dispose()
}