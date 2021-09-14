
$Public = @(Get-ChildItem -Path $PSScriptRoot\public\*.ps1 -ErrorAction SilentlyContinue )
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )
foreach ($function in @($Public + $Private)) {
    try {
        Import-Module $function.FullName -ErrorAction stop
    }
    catch {
        Write-Host "Failed to import $($function.fullname)" -ForegroundColor red
        $_.Exception.Message
        break
    }
}
## Export all of the public functions making them available to the user
foreach ($file in $Public) {
    Export-ModuleMember -Function $file.BaseName
}
