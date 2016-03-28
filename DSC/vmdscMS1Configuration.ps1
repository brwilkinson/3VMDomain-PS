Configuration Main
{
Param ( 
		[String]$DomainName = 'Contoso.com',
		[PSCredential]$AdminCreds,
		[Int]$RetryCount = 20,
		[Int]$RetryIntervalSec = 60
		)

Import-DscResource -ModuleName PSDesiredStateConfiguration
Import-DscResource -ModuleName xComputerManagement
Import-DscResource -ModuleName xActiveDirectory
Import-DscResource -ModuleName xStorage
Import-DscResource -ModuleName xPendingReboot


[PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("$DomainName\$(($AdminCreds.UserName -split '\\')[-1])", $AdminCreds.Password)

Node $AllNodes.Where({$_.Role -eq 'MemberServer'}).NodeName
{
    Write-Verbose -Message $Nodename -Verbose

	LocalConfigurationManager
    {
        ActionAfterReboot   = 'ContinueConfiguration'
        ConfigurationMode   = 'ApplyAndMonitor'
        RebootNodeIfNeeded  = $true
        AllowModuleOverWrite = $true
    }

	WindowsFeatureSet RSAT
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

    xWaitForADDomain $DomainName
    {
        DependsOn  = '[WindowsFeatureSet]RSAT'
        DomainName = $DomainName
        RetryCount = $RetryCount
		RetryIntervalSec = $RetryIntervalSec
        DomainUserCredential = $AdminCreds
    }

	xComputer DomainJoin
	{
		Name       = $Node.NodeName
		DependsOn  = "[xWaitForADDomain]$DomainName"
		DomainName = $DomainName
		Credential = $DomainCreds
	}
    
	# reboots after DJoin
	xPendingReboot RebootForDJoin
    {
        Name      = 'RebootForDJoin'
        DependsOn = '[xComputer]DomainJoin'
    }
}
}#Main


break

# used for troubleshooting

#$Cred = get-credential brw
main -ConfigurationData .\ConfigData.psd1 -AdminCreds $cred -Verbose
Start-DscConfiguration -Path .\Main -Wait -Verbose -Force

Get-DscLocalConfigurationManager

Start-DscConfiguration -UseExisting -Wait -Verbose -Force

Get-DscConfigurationStatus -All