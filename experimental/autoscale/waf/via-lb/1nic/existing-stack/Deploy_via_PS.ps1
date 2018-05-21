## Script parameters being asked for below match to parameters in the azuredeploy.json file, otherwise pointing to the ##
## azuredeploy.parameters.json file for values to use.  Some options below are mandatory, some (such as region) can    ##
## be supplied inline when running this script but if they aren't then the default will be used as specified below.    ##
## Example Command: .\Deploy_via_PS.ps1 -licenseType PAYG -licensedBandwidth 200m -vmScaleSetMinCount 2 -vmScaleSetMaxCount 4 -autoScaleMetric F5_TMM_Traffic -appInsights CREATE_NEW -calculatedBandwidth 200m -scaleOutThreshold 90 -scaleInThreshold 10 -scaleTimeWindow 10 -adminUsername azureuser -authenticationType password -adminPasswordOrKey <value> -dnsLabel <value> -instanceType Standard_DS2_v2 -imageName Best -bigIpVersion 13.1.0200 -vnetName <value> -vnetResourceGroupName <value> -mgmtSubnetName <value> -solutionDeploymentName <value> -applicationProtocols http-https -applicationAddress <value> -applicationServiceFqdn NOT_SPECIFIED -applicationPort 80 -applicationSecurePort 443 -sslCert NOT_SPECIFIED -sslPswd NOT_SPECIFIED -applicationType Linux -blockingLevel medium -customPolicy NOT_SPECIFIED -tenantId <value> -clientId <value> -servicePrincipalSecret <value> -notificationEmail OPTIONAL -ntpServer 0.pool.ntp.org -timeZone UTC -customImage OPTIONAL -allowUsageAnalytics Yes -resourceGroupName <value>

param(
  [string] [Parameter(Mandatory=$True)] $licenseType,
  [string] $licensedBandwidth = $(if($licenseType -like "*PAYG*") { Read-Host -prompt "licensedBandwidth"}),
  [string] $bigIqAddress = $(if($licenseType -like "*BIGIQ*") { Read-Host -prompt "bigIqAddress"}),
  [string] $bigIqUsername = $(if($licenseType -like "*BIGIQ*") { Read-Host -prompt "bigIqUsername"}),
  [string] $bigIqPassword = $(if($licenseType -like "*BIGIQ*") { Read-Host -prompt "bigIqPassword"}),
  [string] $bigIqLicensePoolName = $(if($licenseType -like "*BIGIQ*") { Read-Host -prompt "bigIqLicensePoolName"}),
  [string] $bigIqLicenseSkuKeyword1 = $(if($licenseType -like "*BIGIQ*") { Read-Host -prompt "bigIqLicenseSkuKeyword1"}),
  [string] $bigIqLicenseUnitOfMeasure = $(if($licenseType -like "*BIGIQ*") { Read-Host -prompt "bigIqLicenseUnitOfMeasure"}),
  [string] $numberOfStaticInstances = $(if($licenseType -eq "BIGIQ_PAYG") { Read-Host -prompt "numberOfStaticInstances"}),

  [string] [Parameter(Mandatory=$True)] $vmScaleSetMinCount,
  [string] [Parameter(Mandatory=$True)] $vmScaleSetMaxCount,
  [string] [Parameter(Mandatory=$True)] $autoScaleMetric,
  [string] [Parameter(Mandatory=$True)] $appInsights,
  [string] [Parameter(Mandatory=$True)] $calculatedBandwidth,
  [string] [Parameter(Mandatory=$True)] $scaleOutThreshold,
  [string] [Parameter(Mandatory=$True)] $scaleInThreshold,
  [string] [Parameter(Mandatory=$True)] $scaleTimeWindow,
  [string] [Parameter(Mandatory=$True)] $adminUsername,
  [string] [Parameter(Mandatory=$True)] $authenticationType,
  [string] [Parameter(Mandatory=$True)] $adminPasswordOrKey,
  [string] [Parameter(Mandatory=$True)] $dnsLabel,
  [string] [Parameter(Mandatory=$True)] $instanceType,
  [string] [Parameter(Mandatory=$True)] $imageName,
  [string] [Parameter(Mandatory=$True)] $bigIpVersion,
  [string] [Parameter(Mandatory=$True)] $vnetName,
  [string] [Parameter(Mandatory=$True)] $vnetResourceGroupName,
  [string] [Parameter(Mandatory=$True)] $mgmtSubnetName,
  [string] [Parameter(Mandatory=$True)] $solutionDeploymentName,
  [string] [Parameter(Mandatory=$True)] $applicationProtocols,
  [string] [Parameter(Mandatory=$True)] $applicationAddress,
  [string] [Parameter(Mandatory=$True)] $applicationServiceFqdn,
  [string] [Parameter(Mandatory=$True)] $applicationPort,
  [string] [Parameter(Mandatory=$True)] $applicationSecurePort,
  [string] [Parameter(Mandatory=$True)] $sslCert,
  [string] [Parameter(Mandatory=$True)] $sslPswd,
  [string] [Parameter(Mandatory=$True)] $applicationType,
  [string] [Parameter(Mandatory=$True)] $blockingLevel,
  [string] [Parameter(Mandatory=$True)] $customPolicy,
  [string] [Parameter(Mandatory=$True)] $tenantId,
  [string] [Parameter(Mandatory=$True)] $clientId,
  [string] [Parameter(Mandatory=$True)] $servicePrincipalSecret,
  [string] [Parameter(Mandatory=$True)] $notificationEmail,
  [string] [Parameter(Mandatory=$True)] $ntpServer,
  [string] [Parameter(Mandatory=$True)] $timeZone,
  [string] [Parameter(Mandatory=$True)] $customImage,
  [string] $restrictedSrcAddress = "*",
  $tagValues = '{"application": "APP", "cost": "COST", "environment": "ENV", "group": "GROUP", "owner": "OWNER"}',
  [string] [Parameter(Mandatory=$True)] $allowUsageAnalytics,
  [string] [Parameter(Mandatory=$True)] $resourceGroupName,
  [string] $region = "West US",
  [string] $templateFilePath = "azuredeploy.json",
  [string] $parametersFilePath = "azuredeploy.parameters.json"
)

Write-Host "Disclaimer: Scripting to Deploy F5 Solution templates into Cloud Environments are provided as examples. They will be treated as best effort for issues that occur, feedback is encouraged." -foregroundcolor green
Start-Sleep -s 3

# Connect to Azure, right now it is only interactive login
try {
    Write-Host "Checking if already logged in!"
    Get-AzureRmSubscription | Out-Null
    Write-Host "Already logged in, continuing..."
    }
    catch {
      Write-Host "Not logged in, please login..."
      Login-AzureRmAccount
    }

# Create Resource Group for ARM Deployment
New-AzureRmResourceGroup -Name $resourceGroupName -Location "$region"

$adminPasswordOrKeySecure = ConvertTo-SecureString -String $adminPasswordOrKey -AsPlainText -Force
$sslPswdSecure = ConvertTo-SecureString -String $sslPswd -AsPlainText -Force
$servicePrincipalSecretSecure = ConvertTo-SecureString -String $servicePrincipalSecret -AsPlainText -Force

(ConvertFrom-Json $tagValues).psobject.properties | ForEach -Begin {$tagValues=@{}} -process {$tagValues."$($_.Name)" = $_.Value}

# Create Arm Deployment
if ($licenseType -eq "PAYG") {
  if ($templateFilePath -eq "azuredeploy.json") { $templateFilePath = ".\payg\azuredeploy.json"; $parametersFilePath = ".\payg\azuredeploy.parameters.json" }
  $deployment = New-AzureRmResourceGroupDeployment -Name $resourceGroupName -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath -Verbose -vmScaleSetMinCount $vmScaleSetMinCount -vmScaleSetMaxCount $vmScaleSetMaxCount -autoScaleMetric $autoScaleMetric -appInsights $appInsights -calculatedBandwidth $calculatedBandwidth -scaleOutThreshold $scaleOutThreshold -scaleInThreshold $scaleInThreshold -scaleTimeWindow $scaleTimeWindow -adminUsername $adminUsername -authenticationType $authenticationType -adminPasswordOrKey $adminPasswordOrKeySecure -dnsLabel $dnsLabel -instanceType $instanceType -imageName $imageName -bigIpVersion $bigIpVersion -vnetName $vnetName -vnetResourceGroupName $vnetResourceGroupName -mgmtSubnetName $mgmtSubnetName -solutionDeploymentName $solutionDeploymentName -applicationProtocols $applicationProtocols -applicationAddress $applicationAddress -applicationServiceFqdn $applicationServiceFqdn -applicationPort $applicationPort -applicationSecurePort $applicationSecurePort -sslCert $sslCert -sslPswd $sslPswdSecure -applicationType $applicationType -blockingLevel $blockingLevel -customPolicy $customPolicy -tenantId $tenantId -clientId $clientId -servicePrincipalSecret $servicePrincipalSecretSecure -notificationEmail $notificationEmail -ntpServer $ntpServer -timeZone $timeZone -customImage $customImage -restrictedSrcAddress $restrictedSrcAddress -tagValues $tagValues -allowUsageAnalytics $allowUsageAnalytics  -licensedBandwidth "$licensedBandwidth"
} elseif ($licenseType -eq "BIGIQ") {
  if ($templateFilePath -eq "azuredeploy.json") { $templateFilePath = ".\bigiq\azuredeploy.json"; $parametersFilePath = ".\bigiq\azuredeploy.parameters.json" }
  $bigIqPasswordSecure = ConvertTo-SecureString -String $bigIqPassword -AsPlainText -Force
  $deployment = New-AzureRmResourceGroupDeployment -Name $resourceGroupName -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath -Verbose -vmScaleSetMinCount $vmScaleSetMinCount -vmScaleSetMaxCount $vmScaleSetMaxCount -autoScaleMetric $autoScaleMetric -appInsights $appInsights -calculatedBandwidth $calculatedBandwidth -scaleOutThreshold $scaleOutThreshold -scaleInThreshold $scaleInThreshold -scaleTimeWindow $scaleTimeWindow -adminUsername $adminUsername -authenticationType $authenticationType -adminPasswordOrKey $adminPasswordOrKeySecure -dnsLabel $dnsLabel -instanceType $instanceType -imageName $imageName -bigIpVersion $bigIpVersion -vnetName $vnetName -vnetResourceGroupName $vnetResourceGroupName -mgmtSubnetName $mgmtSubnetName -solutionDeploymentName $solutionDeploymentName -applicationProtocols $applicationProtocols -applicationAddress $applicationAddress -applicationServiceFqdn $applicationServiceFqdn -applicationPort $applicationPort -applicationSecurePort $applicationSecurePort -sslCert $sslCert -sslPswd $sslPswdSecure -applicationType $applicationType -blockingLevel $blockingLevel -customPolicy $customPolicy -tenantId $tenantId -clientId $clientId -servicePrincipalSecret $servicePrincipalSecretSecure -notificationEmail $notificationEmail -ntpServer $ntpServer -timeZone $timeZone -customImage $customImage -restrictedSrcAddress $restrictedSrcAddress -tagValues $tagValues -allowUsageAnalytics $allowUsageAnalytics  -bigIqAddress "$bigIqAddress" -bigIqUsername "$bigIqUsername" -bigIqPassword $bigIqPasswordSecure -bigIqLicensePoolName "$bigIqLicensePoolName" -bigIqLicenseSkuKeyword1 "$bigIqLicenseSkuKeyword1" -bigIqLicenseUnitOfMeasure "$bigIqLicenseUnitOfMeasure"
} elseif ($licenseType -eq "BIGIQ_PAYG") {
  if ($templateFilePath -eq "azuredeploy.json") { $templateFilePath = ".\bigiq-payg\azuredeploy.json"; $parametersFilePath = ".\bigiq-payg\azuredeploy.parameters.json" }
  $bigIqPasswordSecure = ConvertTo-SecureString -String $bigIqPassword -AsPlainText -Force
  $deployment = New-AzureRmResourceGroupDeployment -Name $resourceGroupName -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath -Verbose -vmScaleSetMinCount $vmScaleSetMinCount -vmScaleSetMaxCount $vmScaleSetMaxCount -autoScaleMetric $autoScaleMetric -appInsights $appInsights -calculatedBandwidth $calculatedBandwidth -scaleOutThreshold $scaleOutThreshold -scaleInThreshold $scaleInThreshold -scaleTimeWindow $scaleTimeWindow -adminUsername $adminUsername -authenticationType $authenticationType -adminPasswordOrKey $adminPasswordOrKeySecure -dnsLabel $dnsLabel -instanceType $instanceType -imageName $imageName -bigIpVersion $bigIpVersion -vnetName $vnetName -vnetResourceGroupName $vnetResourceGroupName -mgmtSubnetName $mgmtSubnetName -solutionDeploymentName $solutionDeploymentName -applicationProtocols $applicationProtocols -applicationAddress $applicationAddress -applicationServiceFqdn $applicationServiceFqdn -applicationPort $applicationPort -applicationSecurePort $applicationSecurePort -sslCert $sslCert -sslPswd $sslPswdSecure -applicationType $applicationType -blockingLevel $blockingLevel -customPolicy $customPolicy -tenantId $tenantId -clientId $clientId -servicePrincipalSecret $servicePrincipalSecretSecure -notificationEmail $notificationEmail -ntpServer $ntpServer -timeZone $timeZone -customImage $customImage -restrictedSrcAddress $restrictedSrcAddress -tagValues $tagValues -allowUsageAnalytics $allowUsageAnalytics  -bigIqAddress "$bigIqAddress" -bigIqUsername "$bigIqUsername" -bigIqPassword $bigIqPasswordSecure -bigIqLicensePoolName "$bigIqLicensePoolName" -bigIqLicenseSkuKeyword1 "$bigIqLicenseSkuKeyword1" -bigIqLicenseUnitOfMeasure "$bigIqLicenseUnitOfMeasure" -numberOfStaticInstances $numberOfStaticInstances
} else {
  Write-Error -Message "Please select a valid license type of PAYG, BIGIQ or BIGIQ_PAYG."
}

# Print Output of Deployment to Console
$deployment