

$cred = Get-Credential -UserName "ashis@contosoreseller.onmicrosoft.com" -Message "azure password plz..."

Write-Host "`n[INFO] - Obtaining subscriptions" -ForegroundColor Yellow
[array] $AllSubs = Get-AzureRmSubscription 

If ($AllSubs)
{
        Write-Host "`tSuccess"

        #$AllSubs | FL 
}
Else
{
        Write-Host "`tNo subscriptions found. Exiting." -ForegroundColor Red
        "`tNo subscriptions found. Exiting." 
        Exit
}

Write-Host "`n[SELECTION] - Select the Azure subscription." -ForegroundColor Yellow

$SelSubName = $AllSubs | Out-GridView -PassThru -Title "Select the Azure subscription" 

Login-AzureRmAccount -Credential $cred -TenantId $SelSubName.TenantId -SubscriptionId $SelSubName.SubscriptionId
#Select-AzureRmSubscription -SubscriptionId $SelSubName.SubscriptionId -TenantId $SelSubName.TenantId 
#$ResourceGroupName = "ForMach201"


function Get-VMCount($ResourceGroupName){
    
    try{
        
        Write-Verbose "Getting the number of virtual machines..."
        $VMCount = Get-AzureRmVM -ResourceGroupName $ResourceGroupName
        $VMArray = New-Object System.Collections.ArrayList
        foreach($VM in $VMCount){

            $VMGroupObject = New-Object PSObject -Property @{
            Type=$vm.Type;
            Name=$vm.Name;
            resourceGroupname = $vm.ResourceGroupName;
            DNSName=$vm.OSProfile.ComputerName;
            Location = $vm.Location;
            VmAdminname = $vm.OSProfile.AdminUsername;
            ProvisioningState = $vm.ProvisioningState;
            Offer = $vm.StorageProfile.ImageReference.Offer
            sku = $vm.StorageProfile.ImageReference.Sku
            OSType = $vm.StorageProfile.OsDisk.OsType;
            Extensions = $vm.Extensions
            
            }

        $VMArray.Add($VMGroupObject) | Out-Null
        }
        
        return $VMArray
    }
    catch [System.Exception]{
        Write-Verbose "Exception getting the count of the virtual machines"
        Write-Verbose "Error in getting the count of the virtual machines: $($_.Exception.Message) "
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
		
		Exit $ERRORLEVEL
    }
}

$VMArrayDetails = New-Object System.Collections.ArrayList
$VMArrayDetails = Get-VMCount -ResourceGroupName "ForMach201"

Get-AzureRmSubscription | Format-Table SubscriptionName, IsDefault, IsCurrent, CurrentStorageAccountName
$getStorageAccountDetails = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName
$StorageAccountKey = Get-AzureRmStorageAccountKey -StorageAccountName $getStorageAccountDetails.StorageAccountName -ResourceGroupName $ResourceGroupName
$Ctx = New-AzureStorageContext  $getStorageAccountDetails.StorageAccountName -StorageAccountKey $StorageAccountKey[1].Value
$StorageContainerName = "customscript"
if (Get-AzureStorageContainer -Context $Ctx)
{
    Write-Output -Verbose "$($StorageContainerName) :  Contianer Already exisit"
}
else
{
    Write-Output -Verbose "$($StorageContainerName) :  building Contianer "
    New-AzureStorageContainer -Name $StorageContainerName -Permission Off -Context $Ctx -Verbose
}

$FileName = "GetLocalDisk.ps1"
$File = "C:\Users\ashis\Documents\GitHub\PersonalRepository\GetLocalDisk.ps1"
if (Set-AzureStorageBlobContent -File $File -Blob $FileName -Context $Ctx -Container $StorageContainerName -Force)
{
    
    Write-Output -Verbose "$($StorageContainerName) : $($FileName) : copied successfully "
}
else
{
    Write-Output -Verbose "$($StorageContainerName) : $($FileName) : copying to container had issues. "
}

Set-AzureRmVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $VMArrayDetails.Name -Name DiskDetails `
-StorageAccountName $getStorageAccountDetails.StorageAccountName -StorageAccountKey $StorageAccountKey[1].Value -FileName $FileName `
-Run $FileName -ContainerName $StorageContainerName -Location $vm.Location -TypeHandlerVersion 1.4
  
$output=Get-AzureRmVMCustomScriptExtension -Name $FileName -ResourceGroupName $ResourceGroupName -VMName $VMArrayDetails.Name
Write-Output $output.ProvisioningState

if($output.ProvisioningState -eq "Succeeded")
{
    Write-Output "Code for getDiskDetails executed successfully for the Virtual Machine $($VMArrayDetails.Name)"

}
else
{
    Write-Output "Code for getDiskDetails did not executed successfully for the Virtual Machine $($VMArrayDetails.Name)"
    #throw "Unable to disable firewall for the Virtual Machine $($VMArrayDetails.Name)"
} 






