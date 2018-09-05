Connect-AzureRMAccount
Select-AzureRmSubscription -Subscription "ECOMM PRODUCTION"

$ResourceGroup = "licenseesalesdata-rg"
$SiteName = "licenseesalesdata-web"

$Profile = [xml](Get-AzureRMWebAppPublishingProfile -ResourceGroupName $ResourceGroup -Name $SiteName -Format WebDeploy)
$UserNode = $Profile.FirstChild.ChildNodes[0]

$ApiURL = "https://" + $usernode.publishUrl + "/api/zipdeploy"
$Creds = [CONVERT]::ToBase64String( [Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $userNode.userName, $userNode.userPWD)) )
$Headers = @{Authorization=("Basic {0}" -f $Creds)}

write-Host "Publishing Zip to " + $usernode.publishUrl

Invoke-RestMethod -Uri $APIUrl -ContentType "multipart/form-data" -Headers $Headers -InFile "C:\Users\SMcEnery\Web.zip" -Method POST

