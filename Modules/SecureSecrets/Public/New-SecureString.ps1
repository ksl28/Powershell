function New-SecureString {
    param (
        [parameter(Mandatory=$true)][string]$String,
        [parameter(Mandatory=$true)][string]$Certificate,
        [parameter(Mandatory=$false)][string]$SavePath
    )
    try {
        $CMSMessage = Protect-CmsMessage -To $Certificate -Content $String
        if ($SavePath) {
            $CMSMessage | Out-File -FilePath $SavePath -Encoding utf8 -Force
        }
        else {
            $CMSMessage
        } 
    }
    catch {
       $_.Exception.Message
       break 
    }
    
}