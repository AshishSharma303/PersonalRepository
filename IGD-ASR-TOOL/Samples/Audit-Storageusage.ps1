<# Azure Storage Audit v01

 AzureStorageAudit
 Release Notes
  v01 - initial release with core functionality
  Outputs:
    LogFile 
    Exit 0 | 1 where 1=error
   
#>


  param(
    [Parameter(Mandatory = $false)]
    [bool] $ASMMode,
    [Parameter(Mandatory = $false)]
    [bool]$ARMMode

) # /param 

#=============================================================================# Global Variables#=============================================================================

 [string] $logFile = ".\Audit-Storageusage-Logfile" + ".txt"
          $azureVersion = @("1.5.0","1.5.1")          
          $Global:Prmstorage = @()   
          $PreStorageAcctCnt = 0 
          $Global:VMInfo =@()  
          $Global:VMPremiumdisk =@()
          $global:report = @()     
          $Global:VMPremiumdiskusage =@()
          $Global:VMPremiumdiskMountpointsusage =@()      
#=============================================================================


  function Get-Script-Directory
{
  $invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}


  Function Log-Header
{

 # Lay down a separator to show the start of the script execution 	Log-Message -logfilepath $LogFile -text ("-------------------------------------------------------------------------------") -LogSeverity $false -TimeStampMessage $false -Severity "Info"	Log-Message -logfilepath $LogFile -text "Azure Premium Storage Audit - Script Execution Started" -LogSeverity $false -Severity "Info"}




#=============================================================================# Log messages#=============================================================================#=============================================================================# Log messages# Its a generic function which writes the content to log file in the append mode . # It take filepath text to write as as arguments.# Log File writes the text to file and also display the text in the screen # Function writes the log in the followig format# <Datetime> > <Sevirity> > <text># e.g. 11/17/13 11:45:29 > Info > Tool - Script Execution Started#=============================================================================Function Log-Message {	param ($LogFilePath, [string]$Text, $Severity = "Info", [bool]$LogSeverity = $True, [bool]$TimeStampMessage = $True)	$TextToScreen = $Text	$TextToFile = $Text	# Add the Severity Tag to the text to be logged	$TextToFile = $Severity + " > " + $TextToFile		# Add the TimeStamp Tag to the text to be logged	if ($TimeStampMessage) 	{		$TextToScreen = (Get-Date -UFormat %T) + " > " + $TextToScreen		$TextToFile = (Get-Date -UFormat %m/%d/%y) + " " + (Get-Date -UFormat %T) + " > " + $TextToFile	}	# Log to the screen. Errors in red.	Switch ($Severity)	{		Info	{ Write-Host $TextToScreen }		Error 	{ Write-Host $TextToScreen -ForegroundColor Red}	}	# Log to the file	Out-File -filepath $LogFilePath -append -noClobber -inputObject $TextToFile}

function Azure-Pre-requistes
{


 Log-Message -logfilepath $LogFile -text "Checking Azure PSS module Pre-requisites" -LogSeverity $false -Severity "Info"
 

#============================================================================= # Import Active Directory Module #=============================================================================

  #Log-Message -logfilepath $LogFile -text "Checking Windows Feature - ADDS Tool for PowerShell is enabled in the server " -LogSeverity $false -Severity "Info"
     $errorActionPreference = "silentlycontinue"      $name='Azure' 

 try
 { 
    if(Get-Module -ListAvailable |  
        Where-Object { $_.name -eq $name })  
    {  
        $AS = (Get-Module -ListAvailable | Where-Object{ $_.Name -eq $name }) | Select Version 

        $status = $AzureVersion -match $as.version.tostring()

        If ($status)
        {
             Log-Message -logfilepath $LogFile -text "The Azure PowerShell module installed.”  -LogSeverity $True -Severity "Info"  
             Log-Message -logfilepath $LogFile -text "Checking Azure PSS module Pre-requisites - successful" -LogSeverity $false -Severity "Info" 
        }
        else
        {
            Log-Message -logfilepath $LogFile -text "The Azure PowerShell module is installed but not a supported version.”  -LogSeverity $True -Severity "Error"  
            Log-Message -logfilepath $LogFile -text "Azure Premium Storage Audit - Script Execution Ends with Error " -LogSeverity $True -Severity "Error"
            exit 1
        }
     }  
    else  
    {  
       Log-Message -logfilepath $LogFile -text "The Azure PowerShell module is not installed.”  -LogSeverity $True -Severity "Error"  
       Log-Message -logfilepath $LogFile -text "Azure Premium Storage Audit - Script Execution Ends with Error " -LogSeverity $True -Severity "Error"
       exit 1
    }  }  catch [System.Exception]
  {
            Log-Message -logfilepath $LogFile -text "Error while checking Azure PSS module " -LogSeverity $True -Severity "Error"
            Log-Message -logfilepath $LogFile -text "Error Message: $_.Exception.Message" -LogSeverity $True -Severity "Error"
            Log-Message -logfilepath $LogFile -text "Azure Premium Storage Audit - Script Execution Ends with Error " -LogSeverity $True -Severity "Error"
            exit 1  }	  
}  


#=============================================================================# Login-Azure#=============================================================================
#=============================================================================# SetExchPerm# SetExchPerm function write the users extended AD permission which includes # Send-AS, Recieve-AS & SendTo.#=============================================================================

Function Login-Azure
{

    param ([string]$username )
    $Global:strStatus =""
    $Global:strErrmsg =""

    $Validation = $False
    
        Log-Message -logfilepath $LogFile -text ("Login to Azure Resource Manager (Portal/V2) Subscription process Module execution started") -Severity "Info"
   

        #$cred = Get-Credential -UserName $username -Message "Provide Azure Subscription Account Passsword for login"

        # check the subscription is Classic or ARM

        try
        {
            $status = Login-AzureRmAccount 

        } #/try
        Catch [exception]
        {
             Log-Message -logfilepath $LogFile -text ("An error was encountered while login to Azure Subscription.") -Severity "Info"
             Log-Message -logfilepath $LogFile -text "Error Message: $_.Exception.Message" -LogSeverity $True  -Severity "Error"
             Log-Message -logfilepath $LogFile -text ("Azure Premium Storage Audit - Script Execution Ends with Error") 
             exit 1
         }  # /catch exception 

        Log-Message -logfilepath $LogFile -text ("n[INFO] - Obtaining subscriptions.") -Severity "Info"

        [array] $AllSubs = Get-AzureRmSubscription 

        If ($AllSubs)
        {
             Log-Message -logfilepath $LogFile -text ("Azure Subscription info obtained Sucessfully.") -Severity "Info"
        
                #$AllSubs | FL 
        }
        Else
        {
             Log-Message -logfilepath $LogFile -text ("No Azure Subscription.") -Severity "Info"
             exit 1
        }

             Log-Message -logfilepath $LogFile -text ("[SELECTION] - Select the Azure subscription for Audit..") -Severity "Info"

            $SelSubName = $AllSubs | Out-GridView -PassThru -Title "Select the Azure subscription" 

          #  Login-AzureRmAccount -Credential $cred -TenantId $SelSubName.TenantId -SubscriptionId $SelSubName.SubscriptionId

            try
            {

                $status= Select-AzureRmSubscription -SubscriptionId $SelSubName.SubscriptionId -TenantId $SelSubName.TenantId 
            }
            catch [exception]
            {

             Log-Message -logfilepath $LogFile -text ("An error was encountered while login to Azure Subscription.") -Severity "Info"
             Log-Message -logfilepath $LogFile -text "Error Message: $_.Exception.Message" -LogSeverity $True  -Severity "Error"
             Log-Message -logfilepath $LogFile -text ("Azure Premium Storage Audit - Script Execution Ends with Error") 
             exit 1
                   
            }
                      
                              
}

Function Login-AzureClassicmode
{

    param ([string]$username )
    $Global:strStatus =""
    $Global:strErrmsg =""

    $Validation = $False
    
        Log-Message -logfilepath $LogFile -text ("Login to Azure (Classic/V1) Subscription process Module execution started") -Severity "Info"
   

        #$cred = Get-Credential -UserName $username -Message "Provide Azure Subscription Account Passsword for login"

        # check the subscription is Classic or ARM

        try
        {
            $status = Add-AzureAccount 

        } #/try
        Catch [exception]
        {
             Log-Message -logfilepath $LogFile -text ("An error was encountered while login to Azure Subscription.") -Severity "Info"
             Log-Message -logfilepath $LogFile -text "Error Message: $_.Exception.Message" -LogSeverity $True  -Severity "Error"
             Log-Message -logfilepath $LogFile -text ("Azure Premium Storage Audit - Script Execution Ends with Error") 
             exit 1
         }  # /catch exception 

        Log-Message -logfilepath $LogFile -text ("n[INFO] - Obtaining subscriptions.") -Severity "Info"

        [array] $AllSubs = Get-Azuresubscription 

        If ($AllSubs)
        {
             Log-Message -logfilepath $LogFile -text ("Azure Subscription info obtained Sucessfully.") -Severity "Info"
        
                #$AllSubs | FL 
        }
        Else
        {
             Log-Message -logfilepath $LogFile -text ("No Azure Subscription.") -Severity "Info"
             exit 1
        }

             Log-Message -logfilepath $LogFile -text ("[SELECTION] - Select the Azure subscription for Audit..") -Severity "Info"

            $SelSubName = $AllSubs | Out-GridView -PassThru -Title "Select the Azure subscription" 

            try
            {
               # Set-AzureSubscription -SubscriptionName $SelSubName.SubscriptionId

                $status= Select-AzureSubscription -SubscriptionId $SelSubName.SubscriptionId -current #-TenantId $SelSubName.TenantId 
            }
            catch [exception]
            {

             Log-Message -logfilepath $LogFile -text ("An error was encountered while login to Azure Subscription.") -Severity "Info"
             Log-Message -logfilepath $LogFile -text "Error Message: $_.Exception.Message" -LogSeverity $True  -Severity "Error"
             Log-Message -logfilepath $LogFile -text ("Azure Premium Storage Audit - Script Execution Ends with Error") 
             exit 1
                   
            }
                      
                              
}


Function Get-RMPremiumStorage
{

    try
    {
        $storage = (Get-AzureRmResourceGroup | Get-AzureRmStorageAccount)
    }
    catch [exception]
    {

             Log-Message -logfilepath $LogFile -text ("An error was encountered while fetching the storage account information from Azure Subscription.") -Severity "Info"
             Log-Message -logfilepath $LogFile -text "Error Message: $_.Exception.Message" -LogSeverity $True  -Severity "Error"
             Log-Message -logfilepath $LogFile -text ("Azure Premium Storage Audit - Script Execution Ends with Error") 
             exit 1
                   
     }

    
        If ($storage)
        {
             Log-Message -logfilepath $LogFile -text ("Fetching Storage Account information from the Subscription Successful.") -Severity "Info"
        
             Log-Message -logfilepath $LogFile -text ("Listing the Premium Storage Account information from the Subscription ") -Severity "Info"

        

        }
        Else
        {
             Log-Message -logfilepath $LogFile -text ("No Azure RM Storage Account found in the selected Subscription.") -Severity "Info"
             exit 1
        }

    $pcnt = 0 
    $storage | foreach {  
    
    
        if ($_.Sku.tier -like 'Premium')
        {

            $Record =@{
            StorageAccount =   $_.storageaccountname 
            #Sku = $_.Sku.tier
            }

            $pcnt +=  1
            $Global:Prmstorage  += New-Object PSObject -Property $record

        }

       
    }
        if ($pcnt -gt 0 )
        {
             Log-Message -logfilepath $LogFile -text ("No. of Premium Storage Account in the Subscription : $pcnt.") -Severity "Info"
        }
        else
        {
            Log-Message -logfilepath $LogFile -text ("No Premium Storage Account found in the Subscription : $pcnt.") -Severity "Info"
        }
    
        $PreStorageAcctCnt = $pcnt  
        #$Global:Prmstorage
}

Function Get-ASMPremiumStorage
{

    try
    {
        $storage = ( Get-AzureStorageAccount)
    }
    catch [exception]
    {

             Log-Message -logfilepath $LogFile -text ("An error was encountered while fetching the storage account information from Azure Subscription.") -Severity "Info"
             Log-Message -logfilepath $LogFile -text "Error Message: $_.Exception.Message" -LogSeverity $True  -Severity "Error"
             Log-Message -logfilepath $LogFile -text ("Azure Premium Storage Audit - Script Execution Ends with Error") 
             exit 1
                   
     }

    
        If ($storage)
        {
             Log-Message -logfilepath $LogFile -text ("Fetching Storage Account information from the Subscription Successful.") -Severity "Info"
        
             Log-Message -logfilepath $LogFile -text ("Listing the Premium Storage Account information from the Subscription ") -Severity "Info"

        

        }
        Else
        {
             Log-Message -logfilepath $LogFile -text ("No Azure RM Storage Account found in the selected Subscription.") -Severity "Info"
             exit 1
        }

    $pcnt = 0 
    $storage | foreach {  
    
    
        if ($_.accounttype -like 'Premium*')
        {

            $Record =@{
            StorageAccount =   $_.storageaccountname 
            #Sku = $_.Sku.tier
            }

            $pcnt +=  1
            $Global:Prmstorage  += New-Object PSObject -Property $record

        }

       
    }
        if ($pcnt -gt 0 )
        {
             Log-Message -logfilepath $LogFile -text ("No. of Premium Storage Account in the Subscription : $pcnt.") -Severity "Info"
        }
        else
        {
            Log-Message -logfilepath $LogFile -text ("No Premium Storage Account found in the Subscription : $pcnt.") -Severity "Info"
        }
    
        $PreStorageAcctCnt = $pcnt  
        #$Global:Prmstorage
}


Function Get-RMPremiumStorage
{

    try
    {
        $storage = (Get-AzureRmResourceGroup | Get-AzureRmStorageAccount)
    }
    catch [exception]
    {

             Log-Message -logfilepath $LogFile -text ("An error was encountered while fetching the storage account information from Azure Subscription.") -Severity "Info"
             Log-Message -logfilepath $LogFile -text "Error Message: $_.Exception.Message" -LogSeverity $True  -Severity "Error"
             Log-Message -logfilepath $LogFile -text ("Azure Premium Storage Audit - Script Execution Ends with Error") 
             exit 1
                   
     }

    
        If ($storage)
        {
             Log-Message -logfilepath $LogFile -text ("Fetching Storage Account information from the Subscription Successful.") -Severity "Info"
        
             Log-Message -logfilepath $LogFile -text ("Listing the Premium Storage Account information from the Subscription ") -Severity "Info"

        

        }
        Else
        {
             Log-Message -logfilepath $LogFile -text ("No Azure RM Storage Account found in the selected Subscription.") -Severity "Info"
             exit 1
        }

    $pcnt = 0 
    $storage | foreach {  
    
    
        if ($_.Sku.tier -like 'Premium')
        {

            $Record =@{
            StorageAccount =   $_.storageaccountname 
            #Sku = $_.Sku.tier
            }

            $pcnt +=  1
            $Global:Prmstorage  += New-Object PSObject -Property $record

        }

       
    }
        if ($pcnt -gt 0 )
        {
             Log-Message -logfilepath $LogFile -text ("No. of Premium Storage Account in the Subscription : $pcnt.") -Severity "Info"
        }
        else
        {
            Log-Message -logfilepath $LogFile -text ("No Premium Storage Account found in the Subscription : $pcnt.") -Severity "Info"
        }
    
        $PreStorageAcctCnt = $pcnt  
        #$Global:Prmstorage
}


Function Get-RMPremiumVMDisk
{

    try
    {
        $VM = Get-AzureRmvm
    }
    catch [exception]
    {

             Log-Message -logfilepath $LogFile -text ("An error was encountered while fetching the Azure RM Virtual Machines information from Azure Subscription.") -Severity "Info"
             Log-Message -logfilepath $LogFile -text "Error Message: $_.Exception.Message" -LogSeverity $True  -Severity "Error"
             Log-Message -logfilepath $LogFile -text ("Azure Premium Storage Audit - Script Execution Ends with Error") 
             exit 1
                   
     }
    
        If ($VM)
        {
             Log-Message -logfilepath $LogFile -text ("Fetching Virtual Machine information from the Subscription Successful.") -Severity "Info"
        
             Log-Message -logfilepath $LogFile -text ("Listing the VM Data Disk and Storage type information from the Subscription ") -Severity "Info"
        }
        Else
        {
             Log-Message -logfilepath $LogFile -text ("No VM found in the Azure Subscription.") -Severity "Info"
             exit 1
        }

    $pcnt = 0 
    $VMCnt = 0
    
    $vm | foreach {

     $Vmname = $_.name
     $vmstorage = $_.StorageProfile


        for ($pcnt=0 ; $pcnt -le $vmstorage.DataDisks.Count -1; $pcnt++)
        {  

            $Record =@{
            VMNAme  =   $vmname
            DataDisk = $vmstorage.DataDisks[$pcnt].Vhd.Uri.ToString()
            DisksizeGB = $vmstorage.DataDisks[$pcnt].DiskSizeGB
            disk = $pcnt
            }

            $Global:VMInfo  += New-Object PSObject -Property $record

        }
    
        $VMCnt +=1   
    }

        if ($VMCnt -gt 0 )
        {
             Log-Message -logfilepath $LogFile -text ("No. of VM in in the Subscription : $VMCnt.") -Severity "Info"
        }
        else
        {
            Log-Message -logfilepath $LogFile -text ("No Premium Storage Account found in the Subscription ") -Severity "Info"
        }
    
        #$Global:VMInfo |  Out-GridView -PassThru -Title "Azure RM VM Details" 

         $Global:VMInfo | foreach{

         $datadisk = $_.DataDisk   
         $vmname = $_.VMNAme

         $storagename = $datadisk.substring(7, $datadisk.indexof(".blob.core.windows.net")-7)

         Log-Message -logfilepath $LogFile -text ("Validating VM : $vmname and Disk : $datadisk ") -Severity "Info"
        
         $status = $Global:Prmstorage.storageaccount -contains $storagename
        
        
         if ($status -eq $True)
         {
            $VMRecord =@{
            VMNAme  =   $vmname
            DataDisk = $DataDisk
            DisksizeGB = $_.DiskSizeGB
            Disk = $_.disk 
            }
            
            Log-Message -logfilepath $LogFile -text ("VM : $vmname and Disk : $datadisk is Primium Disk") -Severity "Info"
        
            $Global:VMPremiumdisk += New-Object PSObject -Property $VMrecord
         }
         else
         {
            Log-Message -logfilepath $LogFile -text ("VM : $vmname and Disk : $datadisk is not a Primium Disk") -Severity "Info"
        
         }
                          
        }
        
        $VMScan = $Global:VMPremiumdisk | select vmname, datadisk, disksizegb, disk |  Out-GridView -PassThru -Title "Select the Azure subscription" 

        $VMScan = $Global:VMPremiumdisk | Select-Object -Unique vmname
        
        $VMScan  | Foreach {

       $computername = $_.vmname
        try
        {
            $computername = $_.vmname
            
            Get-RemoteDiskInformation -ComputerName $computername 

           if ( $Global:VMPremiumdiskusage)
           {

                 $disk = $Global:VMPremiumdisk | Where-Object vmname -eq $computername 

                 $disk | foreach {

                        $Diskno = $_.disk
                        #  if ($Diskno -eq 0 )
                        #  {
                        #    $filter = "Disk #0,*"
                        #  }
                        #  else
                        #  {
                            $filter = "Disk #" + ( $Diskno + 2 ).ToString() +",*"
                        #  }

                          $row = $Global:VMPremiumdiskusage | Where-Object {$_.computername -like $computername -and $_.partition -like $filter}

                          if ($row )
                          {
            
                                 $Record2 =@{
                                 VMNAme  =   $_.vmname
                                 DataDisk = $_.DataDisk
                                 DisksizeGB = $Row.DiskSize 
                                 Diskused=$row.UsedSpace 
                                 disk = $_.disk 
                                 volume = $row.volumename
                                 Drive = $row.drive
                                 percentfree = $row.percentfree
                                 percentused = $row.percentused
                                 

                                }
                                $Global:REport  += New-Object PSObject -Property $record2
                           }
            }
            Log-Message -logfilepath $LogFile -text ("Audit the VM Premium disk usage for the VM :$computername completed.") -Severity "Info"
            
        
                    
            }
   
        }
        catch [exception]
        {

             Log-Message -logfilepath $LogFile -text ("An error was encountered while fetching the VM Premium disk usage on the VM :$computername  .") -Severity "Info"
             Log-Message -logfilepath $LogFile -text "Error Message: $_.Exception.Message" -LogSeverity $True  -Severity "Error"
            # Log-Message -logfilepath $LogFile -text ("Azure Premium Storage Audit - Script Execution Ends with Error") 
            # exit 1
                  
        }

}

        

        $VMScan = $Global:report | select vmname, datadisk, disk, drive, volume ,disksizegb,Diskused,percentused ,percentfree|  Out-GridView -PassThru -Title "The Final Premium storage Assessment Report"
        $Global:report | select vmname, datadisk, disk, drive, volume ,disksizegb,Diskused, percentused ,percentfree|  Export-Csv -Path "Audit-StorageUsage-ASMReport.csv" -NoTypeInformation
        
}


Function Get-ASMPremiumVMDisk
{

    try
    {
        $VM = Get-Azurevm
    }
    catch [exception]
    {

             Log-Message -logfilepath $LogFile -text ("An error was encountered while fetching the Azure RM Virtual Machines information from Azure Subscription.") -Severity "Info"
             Log-Message -logfilepath $LogFile -text "Error Message: $_.Exception.Message" -LogSeverity $True  -Severity "Error"
             Log-Message -logfilepath $LogFile -text ("Azure Premium Storage Audit - Script Execution Ends with Error") 
             exit 1
                   
     }
    
        If ($VM)
        {
             Log-Message -logfilepath $LogFile -text ("Fetching Virtual Machine information from the Subscription Successful.") -Severity "Info"
        
             Log-Message -logfilepath $LogFile -text ("Listing the VM Data Disk and Storage type information from the Subscription ") -Severity "Info"
        }
        Else
        {
             Log-Message -logfilepath $LogFile -text ("No VM found in the Azure Subscription.") -Severity "Info"
             exit 1
        }

    $pcnt = 0 
    $VMCnt = 0
    
    $vm | foreach {

     $Vmname = $_.name
     $services = $_.servicename

     $vmstorage = get-azurevm -name $Vmname -ServiceName $services | Get-AzureDataDisk


        for ($pcnt=0 ; $pcnt -le $vmstorage.Count -1; $pcnt++)
        {  
            
            $lun = $vmstorage[$pcnt].lun + 2

            $Record =@{
            VMNAme  =   $vmname
            DataDisk = $vmstorage[$pcnt].MediaLink.AbsoluteUri.ToString()
            DisksizeGB = $vmstorage[$pcnt].LogicalDiskSizeInGB.ToString()
            disk = [string] $lun
            }

            $Global:VMInfo  += New-Object PSObject -Property $record

        }
    
        $VMCnt +=1   
    }

        if ($VMCnt -gt 0 )
        {
             Log-Message -logfilepath $LogFile -text ("No. of VM in in the Subscription : $VMCnt.") -Severity "Info"
        }
        else
        {
            Log-Message -logfilepath $LogFile -text ("No Premium Storage Account found in the Subscription ") -Severity "Info"
        }
    
        #$Global:VMInfo |  Out-GridView -PassThru -Title "Azure RM VM Details" 

         $Global:VMInfo | foreach{

         $datadisk = $_.DataDisk   
         $vmname = $_.VMNAme

         if ($datadisk.contains("https:"))
         {
            $storagename = $datadisk.substring(8, $datadisk.indexof(".blob.core.windows.net")-8)
         }
         else
         {
           $storagename = $datadisk.substring(7, $datadisk.indexof(".blob.core.windows.net")-7)
         }

         Log-Message -logfilepath $LogFile -text ("Validating VM : $vmname and Disk : $datadisk ") -Severity "Info"
        
         $status = $Global:Prmstorage.storageaccount -contains $storagename
        
        
         if ($status -eq $True)
         {
            $VMRecord =@{
            VMNAme  =   $vmname
            DataDisk = $DataDisk
            DisksizeGB = $_.DiskSizeGB
            Disk = $_.disk 
            }
            
            Log-Message -logfilepath $LogFile -text ("VM : $vmname and Disk : $datadisk is Primium Disk") -Severity "Info"
        
            $Global:VMPremiumdisk += New-Object PSObject -Property $VMrecord
         }
         else
         {
            Log-Message -logfilepath $LogFile -text ("VM : $vmname and Disk : $datadisk is not a Primium Disk") -Severity "Info"
        
         }
                          
        }
        
        $VMScan = $Global:VMPremiumdisk | select vmname, datadisk, disksizegb, disk |  Out-GridView -PassThru -Title "Select the Azure subscription" 

        $VMScan = $Global:VMPremiumdisk | Select-Object -Unique vmname
        
        $VMScan  | Foreach {

       $computername = $_.vmname
        try
        {
            $computername = $_.vmname
            
            Get-RemoteDiskInformation -ComputerName $computername 

           if ( $Global:VMPremiumdiskusage)
           {

                 $disk = $Global:VMPremiumdisk | Where-Object vmname -eq $computername 

                 $disk | foreach {

                        $Diskno = $_.disk
                        #  if ($Diskno -eq 0 )
                        #  {
                        #    $filter = "Disk #0,*"
                        #  }
                        #  else
                        #  {
                            $filter = "Disk #" + ( $Diskno ).ToString() +",*"
                        #  }

                          $row = $Global:VMPremiumdiskusage | Where-Object {$_.computername -like $computername -and $_.partition -like $filter}

                          if ($row )
                          {
            
                                 $Record2 =@{
                                 VMNAme  =   $_.vmname
                                 DataDisk = $_.DataDisk
                                 DisksizeGB = $Row.DiskSize 
                                 Diskused=$row.UsedSpace 
                                 disk = $_.disk 
                                 volume = $row.volumename
                                 Drive = $row.drive
                                 percentfree = $row.percentfree
                                 percentused = $row.percentused
                                 

                                }
                                $Global:REport  += New-Object PSObject -Property $record2
                           }
            }
            Log-Message -logfilepath $LogFile -text ("Audit the VM Premium disk usage for the VM :$computername completed.") -Severity "Info"
            
        
                    
            }
   
        }
        catch [exception]
        {

             Log-Message -logfilepath $LogFile -text ("An error was encountered while fetching the VM Premium disk usage on the VM :$computername  .") -Severity "Info"
             Log-Message -logfilepath $LogFile -text "Error Message: $_.Exception.Message" -LogSeverity $True  -Severity "Error"
            # Log-Message -logfilepath $LogFile -text ("Azure Premium Storage Audit - Script Execution Ends with Error") 
            # exit 1
                  
        }

}

        

        $VMScan = $Global:report | select vmname, datadisk, disk, drive, volume ,disksizegb,Diskused,percentused ,percentfree|  Out-GridView -PassThru -Title "The Final Premium storage Assessment Report"
        $Global:report | select vmname, datadisk, disk, drive, volume ,disksizegb,Diskused, percentused ,percentfree|  Export-Csv -Path "Audit-StorageUsage-Report.csv" -NoTypeInformation
        
}
Function Get-RemoteDiskInformation
{
    <#
    .SYNOPSIS
       Get inventory data for specified computer systems.
    .DESCRIPTION
       Gather inventory data for one or more systems using wmi. Data proccessing utilizes multiple runspaces
       and supports custom timeout parameters in case of wmi problems. You can optionally include 
       drive, memory, and network information in the results. You can view verbose information on each 
       runspace thread in realtime with the -Verbose option.
    .PARAMETER ComputerName
       Specifies the target computer for data query.
    #>
    [CmdletBinding()]
    PARAM
    (
        [string[]]   $ComputerName    
    )


          Filter ConvertTo-KMG 
                {
                     <#
                     .Synopsis
                      Converts byte counts to Byte\KB\MB\GB\TB\PB format
                     .DESCRIPTION
                      Accepts an [int64] byte count, and converts to Byte\KB\MB\GB\TB\PB format
                      with decimal precision of 2
                     .EXAMPLE
                     3000 | convertto-kmg
                     #>

                     $bytecount = $_
                        switch ([math]::truncate([math]::log($bytecount,1024))) 
                        {
                            0 {"$bytecount Bytes"}
                            1 {"{0:n2} KB" -f ($bytecount / 1kb)}
                            2 {"{0:n2} MB" -f ($bytecount / 1mb)}
                            3 {"{0:n2} GB" -f ($bytecount / 1gb)}
                            4 {"{0:n2} TB" -f ($bytecount / 1tb)}
                            Default {"{0:n2} PB" -f ($bytecount / 1pb)}
                        }
                }


               $Global:VMPremiumdiskusage =@()
               $Global:VMPremiumdiskMountpointsusage =@() 
                  
                # WMI data
                $wmi_diskdrives = Get-WmiObject -Class Win32_DiskDrive -ComputerName $ComputerName
                $wmi_mountpoints = Get-WmiObject  -ComputerName $ComputerName -Class Win32_Volume -Filter "DriveType=3 AND DriveLetter IS NULL" | Select $WMI_DiskMountProps
                
                $AllDisks = @()
                $DiskElements = @('ComputerName','Disk','Model','Partition','Description','PrimaryPartition','VolumeName','Drive','DiskSize','FreeSpace','UsedSpace','PercentFree','PercentUsed','DiskType','SerialNumber')
                foreach ($diskdrive in $wmi_diskdrives) 
                {
                    $partitionquery = "ASSOCIATORS OF {Win32_DiskDrive.DeviceID=`"$($diskdrive.DeviceID.replace('\','\\'))`"} WHERE AssocClass = Win32_DiskDriveToDiskPartition"
                    $partitions = @(Get-WmiObject -ComputerName $ComputerName -Query $partitionquery)
                    foreach ($partition in $partitions)
                    {
                        $logicaldiskquery = "ASSOCIATORS OF {Win32_DiskPartition.DeviceID=`"$($partition.DeviceID)`"} WHERE AssocClass = Win32_LogicalDiskToPartition"
                        $logicaldisks = @(Get-WmiObject -ComputerName $ComputerName -Query $logicaldiskquery)
                        foreach ($logicaldisk in $logicaldisks)
                        {
                            $PercentFree = [math]::round((($logicaldisk.FreeSpace/$logicaldisk.Size)*100), 2)
                            $UsedSpace = ($logicaldisk.Size - $logicaldisk.FreeSpace)
                            $diskprops = @{
                                           ComputerName = $ComputerName
                                           Disk = $diskdrive.Name
                                           Model = $diskdrive.Model
                                           Partition = $partition.Name
                                           Description = $partition.Description
                                           PrimaryPartition = $partition.PrimaryPartition
                                           VolumeName = $logicaldisk.VolumeName
                                           Drive = $logicaldisk.Name
                                           DiskSize = if ($RawDriveData) { $logicaldisk.Size } else { $logicaldisk.Size | ConvertTo-KMG }
                                           FreeSpace = if ($RawDriveData) { $logicaldisk.FreeSpace } else { $logicaldisk.FreeSpace | ConvertTo-KMG }
                                           UsedSpace = if ($RawDriveData) { $UsedSpace } else { $UsedSpace | ConvertTo-KMG }
                                           PercentFree = $PercentFree
                                           PercentUsed = [math]::round((100 - $PercentFree),2)
                                           DiskType = 'Partition'
                                           SerialNumber = $diskdrive.SerialNumber
                                         }
                                $Global:VMPremiumdiskusage += New-Object psobject -Property $diskprops | Select $DiskElements
                        }
                    }
                }

                # Mountpoints are weird so we do them seperate.
                if ($wmi_mountpoints)
                {
                    foreach ($mountpoint in $wmi_mountpoints)
                    {
                        $PercentFree = [math]::round((($mountpoint.FreeSpace/$mountpoint.Capacity)*100), 2)
                        $UsedSpace = ($mountpoint.Capacity - $mountpoint.FreeSpace)
                        $diskprops = @{
                               ComputerName = $ComputerName
                               Disk = $mountpoint.Name
                               Model = ''
                               Partition = ''
                               Description = $mountpoint.Caption
                               PrimaryPartition = ''
                               VolumeName = ''
                               VolumeSerialNumber = ''
                               Drive = [Regex]::Match($mountpoint.Caption, "(^.:)").Value
                               DiskSize = if ($RawDriveData) { $mountpoint.Capacity } else {} # $mountpoint.Capacity | ConvertTo-KMG }
                               FreeSpace = if ($RawDriveData) { $mountpoint.FreeSpace } else { } #$mountpoint.FreeSpace | ConvertTo-KMG }
                               UsedSpace = if ($RawDriveData) { $UsedSpace } else { } #$UsedSpace | ConvertTo-KMG }
                               PercentFree = $PercentFree
                               PercentUsed = [math]::round((100 - $PercentFree),2)
                               DiskType = 'MountPoint'
                               SerialNumber = $mountpoint.SerialNumber
                             }
                        $Global:VMPremiumdiskMountpointsusage += New-Object psobject -Property $diskprops  | Select $DiskElements
                    }
                }
           
           #$Global:VMPremiumdiskusage 

           #$Global:VMPremiumdiskMountpointsusage
 
       } 




#============================================================================= #Clear Console  Cls
  $error.clear()
#=============================================================================



#=============================================================================# Main code starts#=============================================================================#

#
#
#

if ($ASMMode -eq $true -or $ARMMode -eq $true)
{

    Log-Header

    Azure-Pre-requistes
    
    $ScriptDirectory = Get-Script-Directory

    if ($armmode -eq $true) 
    {

        Login-Azure 

        Get-RMPremiumStorage

        Get-RMPremiumVMDisk

     }

     if ($ASMMode -eq $true) 
    {
        Login-AzureClassicmode
        #################################
        # Reset Global Variables
        $Global:Prmstorage = @()


        #################################


        Get-ASMPremiumStorage

        Get-ASMPremiumVMDisk
    }
}
else
{
 Log-Header
 Log-Message -logfilepath $LogFile -text ("Invalid Parameter provided! .. Choose ASMMode or ARMMode ") 

 Log-Message -logfilepath $LogFile -text ("Azure Premium Storage Audit - Script Execution Ends ") 

}


exit 0
            
