﻿function Wait-VaultConnectivity {
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

    $CyberArkInstallFolder = New-Item -ItemType Directory -Path (Join-Path -Path $LabSources -ChildPath 'SoftwarePackages') -Force

    if ($VisualCRedistributable32) {
        $DesiredBuild = 31938 # 2022
        $InstalledBuild = Get-LabRegistryKeyValue -ComputerName $ComputerName -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\X86' -Name Bld -ErrorAction SilentlyContinue

        if ($InstalledBuild -lt $DesiredBuild -or $null -eq $InstalledBuild) {
            Write-ScreenInfo 'Installing Visual C++ Redistributable 2022 x86'
            $VisualCRedistX86 = Get-LabInternetFile -Uri 'https://aka.ms/vs/17/release/vc_redist.x86.exe' -Path $CyberArkInstallFolder -PassThru
            Install-LabSoftwarePackage -ComputerName $ComputerName -Path $VisualCRedistX86.FullName -CommandLine '/Q'
        }
    }

    if ($VisualCRedistributable64) {
        $DesiredBuild = 31938 # 2022
        $InstalledBuild = Get-LabRegistryKeyValue -ComputerName $ComputerName -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\X64' -Name Bld -ErrorAction SilentlyContinue

        if ($InstalledBuild -lt $DesiredBuild -or $null -eq $InstalledBuild) {
            Write-ScreenInfo 'Installing Visual C++ Redistributable 2022 x64'
            $VisualCRedistX64 = Get-LabInternetFile -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -Path $CyberArkInstallFolder -PassThru
            Install-LabSoftwarePackage -ComputerName $ComputerName -Path $VisualCRedistX64.FullName -CommandLine '/Q'
        }
    }

    if ($DotNetFramework48) {
        $DesiredRelease = 528049 # .NET Framework 4.8.0
        $InstalledRelease = Get-LabRegistryKeyValue -ComputerName $ComputerName -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction SilentlyContinue

        if ($InstalledRelease -lt $DesiredRelease -or $null -eq $InstalledRelease) {
            Write-ScreenInfo 'Installing .NET Framework 4.8'
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

function Get-LabRegistryKeyValue {
    param (
        $ComputerName,
        $Path,
        $Name
    )

    $Value = Invoke-LabCommand -ComputerName $ComputerName -ScriptBlock {
        $ErrorActionPreference = 'SilentlyContinue'
        Get-ItemPropertyValue -Path $args[0] -Name $args[1]
    } -ArgumentList $Path, $Name -NoDisplay -PassThru

    $Value
}