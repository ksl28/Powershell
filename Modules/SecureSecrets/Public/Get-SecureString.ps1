function Get-SecureString {
    param (
        [parameter(Mandatory=$true)]$SecureString
    )
    try {
        $UnsecureString = $SecureString | Unprotect-CmsMessage -ErrorAction stop    
        return $UnsecureString
    }
    catch {
        $_.Exception.Message
        break
    }
    
}