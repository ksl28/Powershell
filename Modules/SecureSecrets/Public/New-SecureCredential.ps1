function New-SecureCredential {
    param (
        [parameter(Mandatory = $true)][pscredential]$Credential,
        [parameter(Mandatory = $true)][string]$Certificate,
        [parameter(Mandatory = $false)][string]$SavePath
    )
    $cred = @{
        username = $Credential.username
        password = $Credential.GetNetworkCredential().Password
    }
    try {
        $CMSMessage = Protect-CmsMessage -To $Certificate -Content ($cred | ConvertTo-Json) -ErrorAction stop
        if ($SavePath) {
            $CMSMessage | Out-File -FilePath $SavePath -Encoding utf8 -Force
        }
        else {
            $CMSMessage
        }    
    }
    catch {
        throw "Failed to create a new secure credential - $($_.Exception.Message)" 
    }
}