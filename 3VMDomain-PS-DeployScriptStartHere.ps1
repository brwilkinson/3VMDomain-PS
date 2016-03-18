﻿#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

# 3VMDomain PowerShell Deployment
# Create a domain with 2 DC's and 1 Member Server using an Azure RM Template

# Once you are logged in and have set the project path, you should be able
# to just update the DeploymentID and press F5 to run the whole script.
# Then you will be prompted for your Admin Password
# Then you will be prompted for the SAS key, it's in the clipboard, 
# just use Ctrl+V to paste it in  : )

# login
#Login-AzureRmAccount

$c = Get-AzureRmContext
 if (-not $c)
 {
    Write-Warning -Message 'Connect to Azure first'
    break
 }

# Just need to fill out these, update the DeploymentID each run (increment by 1)
[validaterange(1,999)]                         [string]$DeploymentID = 100
[validateset('Dev','Test','Prod')]              [string]$Environment = 'Test'
[validateset("Contoso.com","AlpineSkiHouse.com")][String]$DomainName = 'Contoso.com'
[validateset("eastus","eastus2","westus","centralus")][String]$Location  = 'eastus'
                                                      [String]$AdminUser = 'BRW'
$ProjectPath = "$home\Documents\GitHub\3VMDomain-PS"
$TemplateFile = "$ProjectPath\Templates\azuredeploy.json"

# download the vm rdp files after build
$RDPFileDirectory = "$home\Documents\RDP\Azure"

#-------------------------------------------------------------------------------------------------------------------------------
$Deployment = $Environment + $DeploymentID
$rgname    = 'rg' + $Deployment
$saname    = ('sa' + $Deployment).ToLower()     # Lowercase required
$addnsName = ('mycontoso' + $Deployment).ToLower() # Lowercase required

# check that the public dns name $addnsName is available
if (Test-AzureRmDnsAvailability -DomainNameLabel $addnsName -Location $Location)
{
    Write-Verbose "$addnsName is available, all good" -Verbose
}
else
{
    Write-Warning "$addnsName is taken, choose another name"
} 

#-------------------------------------------------------------------------------------------------------------------------------

# For DSC zip archive, Zip all of the DSC stuff up and send it to Azure Blob where it can be picked up by the Azure VM's.

# Storage details just for the Zip for DSC resources * update these just for the first run
$StorageAccountResourceGroupName = 'rgGlobal'
$StorageAccountName              = 'saeastus01'

# Create the connection to read the DSC zip file in blob storage (alternatively you could host the zip file on GitHub)
$StorageContainerName = $rgname.ToLowerInvariant() + '-stageartifacts'
$StorageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName).Key1
$StorageAccountContext = (Get-AzureRmStorageAccount -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName).Context

$StorageTokenParams = @{
	Container  = $StorageContainerName 
	Context    = $StorageAccountContext 
	Permission = 'r'
	ExpiryTime = (Get-Date).AddHours(4) 
	StartTime  = (Get-Date).AddHours(-4) # allow for different timezones and offsets
	}
$ArtifactsLocationSasToken = New-AzureStorageContainerSASToken @StorageTokenParams
$ArtifactsLocationSasToken | Set-Clipboard
#$ArtifactsLocationSasToken = ConvertTo-SecureString -String $ArtifactsLocationSasToken -AsPlainText -Force

$ArtifactsLocation = $StorageAccountContext.BlobEndPoint + $StorageContainerName
$DSCFilePath = "$ProjectPath\DSC\*"
Compress-Archive -Path $DSCFilePath -DestinationPath "$ProjectPath\Staging\dsc.zip" -Force
$AzCopyPath = 'C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe'
& $AzCopyPath "/Source:D:\Azure\DSCTemp", "/Dest:$ArtifactsLocation", "/DestKey:$StorageAccountKey", "/S", "/Y", "/Z:$env:LocalAppData\Microsoft\Azure\AzCopy\$rgname"

#-------------------------------------------------------------------------------------------------------------------------------#>

 # Create new RG, unless you have an alternate to deploy into, this allows update anyway.
New-AzureRmResourceGroup -Name $rgname -Location $Location

# These are the parameters on the deployment that are defined in the JSON template
# they are set above.
$MyParams = @{
    vmDomainName = $DomainName
    DeploymentID = $deploymentID
    Environment  = $environment
    vmAdminUserName = $AdminUser
    _artifactsLocation    = $ArtifactsLocation
    #_artifactsLocationSasToken = # Will get prompted for this just paste it in, when prompted.
}

# Splat the parameters on New-AzureRmResourceGroupDeployment  
$SplatParams = @{
    TemplateFile            = $TemplateFile
    ResourceGroupName       = $rgname 
    TemplateParameterObject = $MyParams
    Name                    = 'ContosoForest'
    Verbose                 = $true
   }

Write-Verbose "The storage sas token key is in the clipboard, so you can just ctrl + V to paste it in to the pop up" -verbose
New-AzureRmResourceGroupDeployment @SplatParams 


# Download the RDP files from the deployment to a chosen directory 
if (Test-Path -Path $RDPFileDirectory)
{
	Get-AzureRmVM -ResourceGroupName $rgname | Foreach {
		Get-AzureRmRemoteDesktopFile -LocalPath ($RDPFileDirectory + '/' + $_.Name + '.RDP') -ResourceGroupName $rgname -Name $_.Name
	}
}

