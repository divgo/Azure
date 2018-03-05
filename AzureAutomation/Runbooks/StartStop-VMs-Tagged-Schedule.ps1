$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
       -ServicePrincipal `
       -TenantId $servicePrincipalConnection.TenantId `
       -ApplicationId $servicePrincipalConnection.ApplicationId `
       -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# Runbooks execute in GMT, so we need to convert it to EST to properly process our schedules
$SystemTime = $(Get-Date).ToUniversalTime(); # Get the current DateTime, in Universal Time
$TZ = [TimeZoneInfo]::FindSystemTimeZoneById("Eastern Standard Time"); # Get an TimeZoneInfo instance in EST
$LocalTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($SystemTime, $TZ); # Convert the GMT Time to EST
$CurrentTime = [int]$LocalTime.ToString("HH:mm").ToString().Replace(":", ""); # Populate a variable with the HH Hours, mm Minutes. Remove the colan and cast to int


# Get Every VM that is tagged with a scheule
Get-AzureRMVM | Where-Object { $_.Tags.ContainsKey("SCHEDULE") } | ForEach {

    $_.Name + " = " + $_.Tags["SCHEDULE"];
    Write-Verbose "Checking VM Tags"

    if ($_.Tags["SCHEDULE"] -ne "AlwaysOn" -And $_.Tags["SCHEDULE"].ToString().Contains("-")) {

        $Schedule = $_.Tags["SCHEDULE"].ToString();
        $StartTime = [int]$Schedule.SubString(0, $Schedule.IndexOf("-"))
        $EndTime = [int]$Schedule.SubString($Schedule.IndexOf("-")+1)
        
        $Schedule + " - StartTime: " + $StartTime + " -- End Time: " + $EndTime + " CurrentTime: " + $CurrentTime

        $IsRunning = $(Get-AzureRMVM -ResourceGroupName $_.ResourceGroupName -Name $_.Name -Status | Where-Object { $_.Statuses.Code -eq 'PowerState/running' }).Count -gt 0
        "IsRunning: " + $IsRunning;

        if ($IsRunning -eq $true) { # Check to see if the machine should be OFF
            "VM is running, checking if it should be"
            if ($CurrentTime -ge $EndTime -Or $CurrentTime -le $StartTime) {
                "Stopping VM: " + $_.Name;
                #Stop-AzureRMVM -Name $_.Name -ResourceGroupName $_.ResourceGroupName -Force
            }
        } else { # Check to see if the machine should be ON
            "VM is NOT running, checking if it should be"
            if ($CurrentTime -ge $StartTime -And $CurrentTime -le $EndTime) {
                "Starting VM: " + $_.Name;
                #Start-AzureRMVM -Name $_.Name -ResourceGroupName $_.ResourceGroupName
            }
        }
    }
}