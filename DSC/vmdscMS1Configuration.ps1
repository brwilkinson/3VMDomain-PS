Configuration Main
{
Param ( 
		[String]$DomainName = 'Contoso.com',
		[PSCredential]$AdminCreds,
		[Int]$RetryCount = 15,
		[Int]$RetryIntervalSec = 60
		)

Import-DscResource -ModuleName PSDesiredStateConfiguration
Import-DscResource -ModuleName xComputerManagement
Import-DscResource -ModuleName xActiveDirectory
Import-DscResource -ModuleName xStorage


[PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("$DomainName\$(($AdminCreds.UserName -split '\\')[-1])", $AdminCreds.Password)

Node $AllNodes.Where({$_.NodeName -eq 'MS1'}).NodeName
{
    Write-Verbose -Message $Nodename -Verbose

	LocalConfigurationManager
    {
        ActionAfterReboot   = 'ContinueConfiguration'
        ConfigurationMode   = 'ApplyAndAutoCorrect'
        RebootNodeIfNeeded  = $true
        AllowModuleOverWrite = $true
    }

	WindowsFeature RSAT
    {            
        Ensure = 'Present'
        Name   = 'RSAT'
		IncludeAllSubFeature = $true
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

	WaitForAny DC1
	{
		NodeName     = '10.0.0.10'
		ResourceName = '[xWaitForADDomain]DC1Forest'
		RetryCount   = $RetryCount
		RetryIntervalSec = $RetryIntervalSec
	}

	xComputer DomainJoin
	{
		Name       = 'MS1'
		DependsOn  = '[WaitForAny]DC1'
		DomainName = $DomainName
		Credential = $DomainCreds
	}

}
}#Main