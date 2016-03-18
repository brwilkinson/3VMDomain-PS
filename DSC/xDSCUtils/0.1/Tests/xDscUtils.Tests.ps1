$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "New-xSelfSignedDscEncryptionCertificate tests" {

    $global:cert = $null
    BeforeEach {
        $global:cert = $null
    }
    AfterEach {
        if ($cert -ne $Null)
        {
            Remove-Item -Force "Cert:\LocalMachine\My\$($cert.Thumbprint)"
        }
    }

    It "Certificate properties" {

        $global:cert = New-xSelfSignedDscEncryptionCertificate -EmailAddress nanalakshmanan@gmail.com

        $cert.Subject | Should be "cn=nanalakshmanan@gmail.com"
        $cert.HasPrivateKey | Should be $true
        $cert.EnhancedKeyUsageList | Should not be $null
        $cert.Extensions | ?{$_.Oid.FriendlyName -eq 'Enhanced Key Usage'} | Should not be $Null
        $cert.Extensions | ?{$_.Oid.FriendlyName -eq 'Key Usage'} | Should not be $Null
        $cert.Extensions | ?{$_.Oid.FriendlyName -eq 'Key Usage'} | %{
            $_.KeyUsages | %{$_ -match 'DataEncipherment'} | Should be $true
            $_.KeyUsages | %{$_ -match 'KeyEncipherment'} | Should be $true
        }
        $cert.NotAfter.Year | Should be ([DateTime]::Now.AddYears(1).Year)
        $cert.GetKeyAlgorithm() | Should be '1.2.840.113549.1.1.1'
    }

    It "Certificate Export" {

        $TempPath = [System.IO.Path]::GetTempFileName()
        $TempFile = "$TempPath.cer"
        $global:cert = New-xSelfSignedDscEncryptionCertificate -EmailAddress nanalakshmanan@gmail.com -ExportFilePath $TempFile
        Test-Path $TempFile | Should be $true
        Remove-Item -Force $TempFile
    }

    It "DSC Encryption test" {

            $TempPath = [System.IO.Path]::GetTempFileName()
            $TempFile = "$TempPath.cer"
            $global:cert = New-xSelfSignedDscEncryptionCertificate -EmailAddress nanalakshmanan@gmail.com -ExportFilePath $TempFile
            $Password = ConvertTo-SecureString -AsPlainText -string 'bar' -for
            $Cred = New-Object System.Management.Automation.PSCredential 'foo', $Password

            configuration test
            {
                Import-DscResource -ModuleName PSDesiredStateConfiguration
                node localhost
                {
                    File f
                    {
                        DestinationPath = "$TempPath\dest"
                        Contents = "Helo world"
                        PsDscRunAsCredential = $cred
                    }
                }
            }

            $ConfigData = @{
                AllNodes = @(
                    @{
                        NodeName = 'localhost'
                        CertificateFile = $TempFile
                    }
                )
            }

            test -outputpath ([System.IO.Path]::GetTempPath()) -ErrorVariable e -ConfigurationData $ConfigData
            $e | should be $null
    }
}
