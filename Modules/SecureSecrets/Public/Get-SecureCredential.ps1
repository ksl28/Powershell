function Get-SecureCredential {
    param (
        [parameter(Mandatory=$true)]$SecureCredential
    )
    try {
        $TempCredential = $SecureCredential | Unprotect-CmsMessage -ErrorAction stop | ConvertFrom-Json 
        #https://pscustomobject.github.io/powershell/howto/PowerShell-Create-Credential-Object/
        $UnsecureCredential = New-Object -type System.Management.Automation.PSCredential ($TempCredential.username, $($TempCredential.password |ConvertTo-SecureString -AsPlainText -Force))
        return $UnsecureCredential   
    }
    catch {
        Write-Host "Failed to decrypt the credentials!" -ForegroundColor red
        $_.Exception.Message
        break
    }
    
} 
