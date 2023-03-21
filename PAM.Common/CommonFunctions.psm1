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