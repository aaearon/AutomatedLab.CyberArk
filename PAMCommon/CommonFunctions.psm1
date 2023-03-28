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

function Wait-VaultConnectivity {
    param (
        $ComputerName,
        $Port = 1858,
        $RetryInterval = 10
    )

    $ProgressPreference = 'SilentlyContinue'

    do {
        Start-Sleep $RetryInterval
    } until (Test-NetConnection $ComputerName -Port $Port -InformationLevel 'Quiet' -WarningAction SilentlyContinue | Where-Object { $_.TcpTestSucceeded })
}

function Install-PAMCommonPreRequisites {
    param (
        $ComputerName,
        $VisualCRedistributable32 = $false,
        $VisualCRedistributable64 = $false,
        $DotNetFramework48 = $false
    )

    $RequiresRestart = $false

    $CyberArkInstallFolder = New-Item -ItemType Directory -Path (Join-Path -Path $LabSources -ChildPath 'CyberArkInstall') -Force

    if ($VisualCRedistributable32) {
        $DesiredBuild = 31938 # 2022
        $InstalledBuild = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\X86' -Name Bld

        if ($InstalledBuild -ne $DesiredBuild -or $null -eq $InstalledBuild) {
            $VisualCRedistX86 = Get-LabInternetFile -Uri 'https://aka.ms/vs/17/release/vc_redist.x86.exe' -Path $CyberArkInstallFolder -PassThru
            Install-LabSoftwarePackage -ComputerName $ComputerName -Path $VisualCRedistX86.FullName -CommandLine '/Q'
        }
    }

    if ($VisualCRedistributable64) {
        $DesiredBuild = 31938 # 2022
        $InstalledBuild = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\X86' -Name Bld

        if ($InstalledBuild -ne $DesiredBuild -or $null -eq $InstalledBuild) {
            $VisualCRedistX64 = Get-LabInternetFile -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -Path $CyberArkInstallFolder -PassThru
            Install-LabSoftwarePackage -ComputerName $ComputerName -Path $VisualCRedistX64.FullName -CommandLine '/Q'
        }
    }

    if ($DotNetFramework48) {
        $DesiredRelease = 528040 # .NET Framework 4.8
        $InstalledRelease = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release

        if ($InstalledRelease -lt $DesiredRelease -or $null -eq $InstalledRelease) {
            $RequiresRestart = $true
            $DotNetFramework48 = Get-LabInternetFile -Uri 'https://go.microsoft.com/fwlink/?linkid=2088631' -Path $CyberArkInstallFolder -PassThru
            Install-LabSoftwarePackage -ComputerName $ComputerName -Path $DotNetFramework48.FullName -CommandLine '/install /quiet /norestart'
        }
    }

    if ($RequiresRestart) {
        Write-ScreenInfo 'Restarting as pre-requisites require a restart'
        Restart-LabVM -ComputerName $ComputerName -Wait
    }
}
