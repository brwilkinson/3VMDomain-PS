#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

# 3VMDomain PowerShell Deployment
# Create a domain with 2 DC's and 1 Member Server using an Azure RM Template

# Once you are logged in to Azure
# Set the project path
# Update the DeploymentID and press F5 to run the whole script.
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
[validaterange(1,999)]                      [string]$DeploymentID = 354
[validateset('Dev','Test','Prod')]          [string]$Environment = 'Test'
[ValidateSet("Standard_LRS","Standard_GRS")][String]$StorageType = "Standard_LRS"
[validateset("Contoso.com","AlpineSkiHouse.com")][String]$DomainName = 'Contoso.com'
[validateset("eastus","eastus2","westus","centralus")][String]$Location  = 'eastus'
                                                      [String]$AdminUser = 'ARMAdmin'
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
# I actually append the name of the DC onto the end of the addnsname
if (Test-AzureRmDnsAvailability -DomainNameLabel $addnsName -Location $Location)
{
    Write-Verbose "$addnsName is available, all good" -Verbose
}
else
{
    Write-Warning "$addnsName is taken, choose another name"
    break
}

 # Create new RG, unless you have an alternate to deploy into, this allows update anyway.
New-AzureRmResourceGroup -Name $rgname -Location $Location

#-------------------------------------------------------------------------------------------------------------------------------

# For DSC zip archive, Zip all of the DSC stuff up and send it to Azure Blob where it can be picked up by the Azure VM's.

# Storage details just for the Zip for DSC resources * update these just for the first run
$StorageAccountResourceGroupName = 'rgGlobal'
$StorageAccountName              = 'saeastus01'
try {
    # Create the connection to read the DSC zip file in blob storage (alternatively you could host the zip file on GitHub)
    $StorageContainerName = $rgname.ToLowerInvariant() + '-stageartifactps'
    $StorageAccountKey = (Get-AzureRmStorageAccountKey -EA stop -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName)[0].Key1
    $StorageAccountContext = (Get-AzureRmStorageAccount -EA stop -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName)[0].Context
}
Catch
{
    $_
    write-warning -Message "Setup the storage account for your DSC assets first"
    break
}

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
& $AzCopyPath "/Source:$ProjectPath\Staging", "/Dest:$ArtifactsLocation", "/DestKey:$StorageAccountKey", "/S", "/Y", "/Z:$env:LocalAppData\Microsoft\Azure\AzCopy\$rgname"

#-------------------------------------------------------------------------------------------------------------------------------#>

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
    Name                    = 'LABContosoForest'
    Verbose                 = $true
    Force                   = $true
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
else
{
    Write-warning -Message "if you set the `$RDPFileDirectory path, the script will download the Azure VM RDP files for you"
}


break

# Using the following to check the DSC Extension status if they did not succeed
Get-AzureRmVM -ResourceGroupName $rgname -PipelineVariable VM | Foreach {      # vmTest635MS1/vmdscMS1                
$VMName = $VM.Name
$ExtName = "vmdsc" + (-join $VMName[-3..-1])
    Write-Verbose -Message $VMName -Verbose
    Get-AzureRmVMDscExtension -ResourceGroupName $rgname -VMName $VMName -Name $ExtName -OutVariable status

    if ($status.ProvisioningState -ne 'Succeeded')
    {
        Get-AzureRmVMDscExtensionStatus -ResourceGroupName $rgname -VMName $VMName -Name $ExtName | ForEach-Object {
            
            Write-Verbose -Message $_.Status -Verbose
            Write-Verbose -Message $_.StatusMessage -Verbose
            $_.DscConfigurationLog
        }
    }
}

# Optionally connect to the VM's in a scaled size RDP window
# https://gallery.technet.microsoft.com/scriptcenter/Start-RDP-MSTSC-in-a-74367a0d
Start-Rdp -FilePath ($RDPFileDirectory + "\vm${Deployment}DC1.rdp")
Start-Rdp -FilePath ($RDPFileDirectory + "\vm${Deployment}DC2.rdp")
Start-Rdp -FilePath ($RDPFileDirectory + "\vm${Deployment}MS1.rdp")