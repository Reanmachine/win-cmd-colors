$ThemesPath = Resolve-Path (Join-Path (Get-Location) "./themes")
$DistPath = Resolve-Path (Join-Path (Get-Location) "./dist")
$ConsoleNames = @(
    "Black",
    "Blue",
    "Green",
    "Aqua",
    "Red",
    "Purple",
    "Yellow",
    "White",
    "Gray",
    "LightBlue",
    "LightGreen",
    "LightAqua",
    "LightRed",
    "LightPurple",
    "LightYellow",
    "BrightWhite"
)
$HexPattern = "([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})"

Function Get-GitVersion {
    return (git log -n 1 --oneline --format="format:%H")
}

Function Format-RightPad($Value, $Length) {
    $Builder = [System.Text.StringBuilder]::new()
    $Builder.Append($Value) | Out-Null

    for ($i = $Value.Length - 1; $i -lt $Length; $i++) {
        $Builder.Append(' ') | Out-Null
    }

    return $Builder.ToString()
}

Function Format-DwordHex($Hex)
{
    if ($Hex -NotMatch $HexPattern) {
        throw ("Invalid Hex: {0}" -f $Hex)
    }

    return $Hex -Replace $HexPattern, "00`$3`$2`$1"
}

Write-Output "[X] Building Themes"
Write-Output (" - Themes: {0}" -f $ThemesPath)
Write-Output (" - Dist:   {0}" -f $DistPath)

# Clean Dist folder
Write-Output "[X] Cleaning Dist"
if (Test-Path "./dist") 
{
    Write-Output " - Cleaned"
    Remove-Item "./dist" -Force -Recurse | Out-Null
}
else 
{
    Write-Output " - Not Found"
}

Write-Output "[X] Creating Dist"
New-Item -Path $DistPath -ItemType Directory | Out-Null

# Go through each themes
Write-Output "[X] Parsing Themes"
$Themes = Get-ChildItem -Path $ThemesPath
foreach($Theme in $Themes) 
{
    $ThemePath = $Theme.FullName
    $ThemeData = (Get-Content $ThemePath) -Join "`n" | ConvertFrom-Json

    Write-Output (" - Building Theme: {0}" -f $ThemeData.Name)

    # Header
    $Contents = @(
        "Windows Registry Editor Version 5.00",
        "",
        "; ===============================================================",
        ("; == win-cmd-colors - {0}" -f $ThemeData.Description),
        ("; == Changeset: {0}" -f (Get-GitVersion))
        ";"
    )

    # Build Human-Readable Table
    $Index = 0
    $NameWidth = ($ThemeData.Colors | % { $_.Key.Length } | Measure-Object -Maximum).Maximum
    $ThemeData.Colors | % {
        $Data = (
            $Index,
            (Format-RightPad $ConsoleNames[$Index] 15),
            (Format-RightPad $_.Key $NameWidth),
            $_.Color
        )

        $Contents += ("; {0:00} {1} {2} #{3}" -f $Data)
        $Index++
    }

    # Build Reg Table
    $Contents += @(
        ";",
        "",
        "[HKEY_CURRENT_USER\Console]"
    )

    $Index = 0
    $ThemeData.Colors | % {
        $Data = (
            $Index,
            (Format-DwordHex $_.Color)
        )

        $Contents += ("`"ColorTable{0:00}`"=dword:{1}" -f $Data)
        $Index++
    }

    # Build Reg Settings
    $Contents += ("`"ScreenColors`"=dword:000000{0:x}{1:x}" -f ($ThemeData.ScreenColors.Background, $ThemeData.ScreenColors.Foreground))
    $Contents += ("`"PopupColors`"=dword:000000{0:x}{1:x}" -f ($ThemeData.PopupColors.Background, $ThemeData.PopupColors.Foreground))

    # Output Theme
    $Filename = "{0}.reg" -f [System.IO.Path]::GetFileNameWithoutExtension($Theme.Name);
    $OutputPath = Join-Path $DistPath $Filename

    $Contents | Set-Content -Path $OutputPath -Encoding Ascii
}