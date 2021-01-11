function New-SecureCertificate {
    param (
        [parameter(Mandatory=$true)][string]$DNSName,
        [parameter(Mandatory=$true)][int]$YearsValid
    )
    $CertValues = @{
        Subject             = "CN=$DNSName"
        KeyLength           = "4096"
        KeyAlgorithm        = "RSA"
        CertStoreLocation   = "Cert:\CurrentUser\My"
        KeyUsage            = "DataEncipherment"
        Type                = "DocumentEncryptionCert"
        NotAfter            = $(Get-Date).AddYears($YearsValid)
    }
    New-SelfSignedCertificate @CertValues
}
