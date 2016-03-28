Configuration Main
{
Param ( 
		[String]$DomainName = 'Contoso.com',
		[PSCredential]$AdminCreds,
		[Int]$RetryCount = 15,
		[Int]$RetryIntervalSec = 60
		)

Import-DscResource -ModuleName PSDesiredStateConfiguration
Import-DscResource -ModuleName xActiveDirectory
Import-DscResource -ModuleName xStorage

[PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("$DomainName\$($AdminCreds.UserName)", $AdminCreds.Password)

Node $AllNodes.Where({$_.Role -eq 'PDC'}).NodeName
{
    Write-Verbose -Message $Nodename -Verbose

	LocalConfigurationManager
    {
        ActionAfterReboot   = 'ContinueConfiguration'
        ConfigurationMode   = 'ApplyAndMonitor'
        RebootNodeIfNeeded  = $true
        AllowModuleOverWrite = $true
    }

    WindowsFeature InstallADDS
    {            
        Ensure = "Present"
        Name = "AD-Domain-Services"
    }

	xDisk FDrive
    {
        DiskNumber  = 2
        DriveLetter = 'F'
    }

	File TestFile
	{
		DestinationPath = $Node.Path
		Contents        = $Node.NodeName
		DependsOn       = '[xDisk]FDrive'
	}

    xADDomain DC1
    {
        DomainName = $DomainName
        DomainAdministratorCredential = $DomainCreds
        SafemodeAdministratorPassword = $DomainCreds
        DatabasePath = 'F:\NTDS'
        LogPath      = 'F:\NTDS'
        SysvolPath   = 'F:\SYSVOL'
        DependsOn = "[WindowsFeature]InstallADDS","[xDisk]FDrive"
    }

    xWaitForADDomain DC1Forest
    {
        DomainName           = $DomainName
        DomainUserCredential = $DomainCreds
        RetryCount           = $RetryCount
        RetryIntervalSec     = $RetryIntervalSec
        DependsOn = "[xADDomain]DC1"
    } 

    xADRecycleBin RecycleBin
    {
        EnterpriseAdministratorCredential = $DomainCreds
        ForestFQDN                        = $DomainName
        DependsOn = '[xWaitForADDomain]DC1Forest'
    }

}
}#Main