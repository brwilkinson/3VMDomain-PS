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
Import-DscResource -ModuleName xPendingReboot

[PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("$DomainName\$(($AdminCreds.UserName -split '\\')[-1])", $AdminCreds.Password)

Node $AllNodes.Where({$_.NodeName -eq 'DC2'}).NodeName
{
    Write-Verbose -Message $Nodename -Verbose

	LocalConfigurationManager
    {
        ActionAfterReboot   = 'ContinueConfiguration'
        ConfigurationMode   = 'ApplyAndAutoCorrect'
        RebootNodeIfNeeded  = $true
        AllowModuleOverWrite = $true
    }

    WindowsFeature InstallADDS
    {            
        Ensure = 'Present'
        Name   = 'AD-Domain-Services'
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

    xPendingReboot RebootForFreshDNS
    {
        Name      = 'RebootForFreshDNS'
        DependsOn = '[File]TestFile'
    }

	Script RebootForFreshDNS
    {
        DependsOn = '[xPendingReboot]RebootForFreshDNS'
        GetScript = {Get-DnsClientServerAddress -AddressFamily IPv4 -InterfaceAlias Ethernet |
                        Select ServerAddresses   
                     }
        SetScript = {$global:DSCMachineStatus = 1}
        TestScript = {Get-DnsClientServerAddress -AddressFamily IPv4 -InterfaceAlias Ethernet |
                       foreach {! ($_.ServerAddresses -contains '8.8.8.8')}}
    }

    xWaitForADDomain $DomainName
    {
        DependsOn  = '[Script]RebootForFreshDNS'
        DomainName = $DomainName
        RetryCount = $RetryCount
		RetryIntervalSec = $RetryIntervalSec
        DomainUserCredential = $AdminCreds
    }

	xADDomainController DC2
	{
		DependsOn    = '[WindowsFeature]InstallADDS',"[xWaitForADDomain]$DomainName"
		DomainName   = $DomainName
		DatabasePath = 'F:\NTDS'
        LogPath      = 'F:\NTDS'
        SysvolPath   = 'F:\SYSVOL'
        DomainAdministratorCredential = $DomainCreds
        SafemodeAdministratorPassword = $AdminCreds
		PsDscRunAsCredential = $AdminCreds
	}

    xPendingReboot RebootForFun
    {
        Name      = 'RebootForFun'
        DependsOn = '[xADDomainController]DC2'
    }

}#Node
}#Main