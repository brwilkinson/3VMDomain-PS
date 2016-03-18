<#
.Synopsis
   Generate self signed certificate for credential encryption in DSC
.DESCRIPTION
   Uses New-SelfSignedCertificate cmdlet to create a certificate that meets
   all requirements for encrypting a credential in DSC. The certificate
   will be placed in cert:\LocalMachine\my
.EXAMPLE
   New-xSelfSignedDscEncryptionCertificate -EmailAddress nanalakshmanan@gmail.com
.EXAMPLE
   New-xSelfSignedDscEncryptionCertificate -EmailAddress nanalakshmanan@gmail.com -ValidityYears 2
.EXAMPLE
   New-xSelfSignedDscEncryptionCertificate -EmailAddress nanalakshmanan@gmail.com -ExportFilePath D:\MyCerts
#>

function New-xSelfSignedDscEncryptionCertificate
{
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    Param
    (
        [Parameter(Position=0, Mandatory=$true)]
        [string]
        $EmailAddress,

        [Parameter()]
        [int]
        [ValidateRange(1, 5)]
        $ValidityYears=1,

        [Parameter()]
        [string]
        $ExportFilePath
    )

    # OID for document encryption
    $Oid = New-Object System.Security.Cryptography.Oid "1.3.6.1.4.1.311.80.1"
    $oidCollection = New-Object System.Security.Cryptography.OidCollection
    $oidCollection.Add($oid) > $Null

    # Create enhanced key usage extension that allows document encryption
    $Ext = New-Object System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension $oidCollection, $true 

    Write-Verbose 'Creating self signed cert in user store'
    $cert = New-SelfSignedCertificate -Subject "cn=$EMailAddress" `
                                -KeyLength 2048 `
                                -KeySpec KeyExchange `
                                -HashAlgorithm sha256 `
                                -KeyExportPolicy Exportable `
                                -KeyUsage KeyEncipherment, DataEncipherment `
                                -Extension $Ext `
                                -NotAfter ([datetime]::Now.AddYears($ValidityYears)) 

    $cert 

    if ([string]::IsNullOrEmpty($ExportFilePath))
    {
        return
    }

    if (Test-Path $ExportFilePath)
    {
        throw "$ExportFilePath already exists, if you want to override manually delete and use Export-Certificate cmdlet"
    }

    Write-Verbose "Exporting certificate with thumbprint $($cert.Thumbprint) to $ExportFilePath"
    Export-Certificate -Cert $cert -Type CERT -FilePath $ExportFilePath > $null
}

