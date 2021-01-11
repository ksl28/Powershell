# SecureSecrets by Microsoft CMS

## Description:
Powershell module to secure strings and credentials, based on an certificate.  
Its build around Microsofts official CMS modules.
https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/protect-cmsmessage?view=powershell-7.1
https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/unprotect-cmsmessage?view=powershell-7.1

## Requirements:
Powershell 5 or higher.  

## Installation:
Import-module C:\path\to\file\SecureSecrets.psm1 -force

## Exampls:
**New-SecureCertificate**
New-SecureCertificate -DNSName "CertExample" -YearsValid 2

**New-SecureString**
$Cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object {$_.Subject -eq "CN=CertExample"}
New-SecureString -String "this is amazing!" -Certificate $Cert.Subject -SavePath C:\path\to\secret.txt

**New-SecureCredential**
$Cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object {$_.Subject -eq "CN=CertExample"}
New-SecureCredential -Credential $(Get-Credential) -Certificate $Cert.Subject -SavePath C:\path\to\secret.txt

**Get-SecureCredential**
$credfile = Get-SecureCredential -SecureCredential $(Get-Content C:\path\to\secret.txt)
New-PSSession -ComputerName "server.domain.tld" -Credential $credfile

**Get-SecureString**
Get-SecureString -SecureString $(Get-Content C:\path\to\secret.txt)