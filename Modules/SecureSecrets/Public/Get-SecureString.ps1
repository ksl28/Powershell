function Get-SecureString {
    param (
        [parameter(Mandatory=$true)]$SecureString
    )
    try {
        $SecureString | Unprotect-CmsMessage -ErrorAction stop    
        return $SecureString
    }
    catch {
        $_.Exception.Message
        break
    }
    
}