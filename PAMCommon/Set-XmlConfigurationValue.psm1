function Set-XmlConfigurationValue {
    param (
        $Path,
        $Parameter,
        $Value
    )

    $Xml = [xml](Get-Content $Path)
    $Element = $Xml.SelectSingleNode("//Parameter[@Name='$Parameter']")
    $Element.Value = $Value
    $Xml.Save($Path)
}