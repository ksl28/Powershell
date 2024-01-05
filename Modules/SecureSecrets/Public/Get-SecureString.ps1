function Get-SecureString {
    param (
        [parameter(Mandatory=$true)]$SecureString
    )
    try {
        $UnsecureString = $SecureString | Unprotect-CmsMessage -ErrorAction stop    
        return $UnsecureString
    }
    catch {
        throw "Failed to decrypt the Secure string - $($_.Exception.Message)"
    }
    
}