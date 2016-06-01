#CSP Portal COnnection to contoso
# $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList @($username,(ConvertTo-SecureString -String $password -AsPlainText -Force))
# Login-AzureRmAccount 
# Select-AzureRmSubscription -SubscriptionId e3d5a715-fd29-4509-9dac-5ca7f49fb1a0
# get-azurermvm | select Name



workflow Start-VM 
{
    Param
    (
        [string] $ResourceGroupName = "RDS-Basic-501",
        [String] $VMname = "RemoteM",
        [String] $username = "ashishsharma303@hotmail.com"
        
    )

# $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList @($username,(ConvertTo-SecureString -String $password -AsPlainText -Force))
    add-AzureRmAccount
    Select-AzureRmSubscription -SubscriptionId e3d5a715-fd29-4509-9dac-5ca7f49fb1a0 -TenantId 72f988bf-86f1-41af-91ab-2d7cd011db47


$getResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName
# Write-Output $getResourceGroup
    if ($getResourceGroup)
    {
        $Vmcollection = Get-AzureRmVM -ResourceGroupName $ResourceGroupName
       
        foreach -parallel ($item in $VMcollection)
        {
            #Write-Output "value of item : $($item.name)"
            inlineScript
            {
                #Login-AzureRmAccount
                Select-AzureRmSubscription -SubscriptionId e3d5a715-fd29-4509-9dac-5ca7f49fb1a0
                Write-Output $($using:item.Name)
                Write-Output $using:ResourceGroupName
                Start-AzureRmVM -Name $($using:item.Name) -ResourceGroupName $using:ResourceGroupName
            } # Optional workflow common parameters such as -PSComputerName and -PSCredential
            
            
            #Get-AzureRmVM -Name $item.Name -ResourceGroupName $ResourceGroupName | Start-AzureRmVM -Verbose
        
        }
    }
    else
    {
        Write-Output "Error: not able to find the resource group $($ResourceGroupName).."
    }


}

Start-VM

