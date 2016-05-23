#region - Global Script Variables
PARAM
(   [CmdletBinding()]
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionID = "7ee1eff3-2d88-497e-a48c-89f716ada306",
    [Parameter(Mandatory = $false)]
    [string]$FolderPath

)

$Script:Path = Get-Location
$Script:ComputerName = $env:ComputerName

#Setting up the Log File
$timestamp = Get-Date -format yyyy-MM-dd-HHmmss
$CurrentScriptFileName = $MyInvocation.MyCommand.Name
$LogFileName = $CurrentScriptFileName.Split(".ps1")[0] + "_" + $timestamp + ".log"
$Script:ScriptLog = "$Path\$LogFileName"

$ERRORLEVEL = -1

#endregion

#region - Script Functions
<#
 ==============================================================================================	 
	Script Functions
    Get-IsElevated					- Checks if the script is in an elevated PS session		
 ==============================================================================================	
#>
function Get-IsElevated
{
	# Get the ID and security principal of the current user account
	$WindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent()
	$WindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($WindowsID)
	
	# Get the security principal for the Administrator role
	$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
	
	# Check to see if currently running "as Administrator"
	if ($WindowsPrincipal.IsInRole($adminRole))
	{
		return $True
	}
	else
	{
		return $False
	}
}

function Get-VMCount{
    
    try{
        
        Write-Verbose "Getting the number of virtual machines..."
        $VMCount = (Get-AzureVM)
        $VMArray = New-Object System.Collections.ArrayList
        foreach($VM in $VMCount){
            $DataDisks = $vm| Get-AzureDataDisk 
            $Endpoints = $vm| Get-AzureEndpoint 

            $Location=(Get-AzureService -ServiceName $vm.ServiceName).Location

            $VMGroupObject = New-Object PSObject -Property @{
            Type="VM";
            Name=$vm.Name;
            azureVm=$vm.VM;
            AvailabilitySetName=$vm.AvailabilitySetName;
            DeploymentName=$vm.DeploymentName;
            DNSName=$vm.DNSName;
            GuestAgentStatus=$vm.GuestAgentStatus;
            HostName=$vm.HostName;
            InstanceErrorCode=$vm.InstanceErrorCode;
            InstanceFaultDomain=$vm.InstanceFaultDomain;
            InstanceName=$vm.InstanceName;
            InstanceSize=$vm.InstanceSize;
            InstanceStateDetails=$vm.InstanceStateDetails;
            InstanceStatus=$vm.InstanceStatus;
            InstanceUpgradeDomain=$vm.InstanceUpgradeDomain;
            IpAddress=$vm.IpAddress;
            Label=$vm.Label;
            NetworkInterfaces=$vm.NetworkInterfaces;
            OperationDescription=$vm.OperationDescription;
            OperationId=$vm.OperationId;
            OperationStatus=$vm.OperationStatus;
            PowerState=$vm.PowerState;
            PublicIPAddress=$vm.PublicIPAddress;
            PublicIPName=$vm.PublicIPName;
            ResourceExtensionStatusList=$vm.ResourceExtensionStatusList;
            ServiceName=$vm.ServiceName;
            Status=$vm.Status;
            VirtualNetworkName=$vm.VirtualNetworkName;
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
		Stop-Transcript
		Exit $ERRORLEVEL
    }
}

function Get-EndpointCount{
    
    try{
        
        Write-Verbose "Getting the number of endpoints..."
        $VMCount = (Get-AzureVM)
        $EndpointArray = New-Object System.Collections.ArrayList
        foreach($VM in $VMCount){
          $Endpoints = $vm| Get-AzureEndpoint 
          foreach($endpoint in $Endpoints)
            {
            $EndpointObject = New-Object PSObject -Property @{
                VMName = $vm.Name;
                Type = "Endpoint";
                EndpointName=$endpoint.Name;
                EndpointLocalPort=$endpoint.LocalPort;
                EndpointPublicPort=$endpoint.Port;
                Protocol=$endpoint.Protocol;
                Vip=$endpoint.Vip;
                LBSetName=$endpoint.LBSetName;
                Acl=$endpoint.Acl;
                InternalLoadBalancerName=$endpoint.InternalLoadBalancerName;
                IdleTimeoutInMinutes=$endpoint.IdleTimeoutInMinutes;
                VirtualIPName=$endpoint.VirtualIPName;
                ProbePort = $endpoint.ProbePort;
                ProbeProtocol = $endpoint.ProbeProtocol;
            }

            $EndpointArray.Add($EndpointObject) | Out-Null




            }
        }
        return $EndpointArray
    }
    catch [System.Exception]{
        Write-Verbose "Exception getting the count of the endpoint"
        Write-Verbose "Error in getting the count of the endpoints: $($_.Exception.Message) "
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
		Stop-Transcript
		Exit $ERRORLEVEL
    }
}

function Get-OSDataDisk{
    
    try{
        
        Write-Verbose "Getting the number of endpoints..."
        $VMCount = (Get-AzureVM)
        $DDArray = New-Object System.Collections.ArrayList
        foreach($VM in $VMCount){
          $DataDisks = $vm| Get-AzureDataDisk 
          foreach($DataDisk in $DataDisks)
          {
            $DataDiskObject = New-Object PSObject -Property @{
                Type = "OSDataDisk";
                DiskName=$DataDisk.DiskName;
                DiskLabel=$DataDisk.DiskLabel;
                HostCaching=$DataDisk.HostCaching;
                Lun=$DataDisk.Lun;
                LogicalDiskSizeInGB=$DataDisk.LogicalDiskSizeInGB;
                MediaLink=$DataDisk.MediaLink;
                IOType=$DataDisk.IOType;
            }
           $DDArray.Add($DataDiskObject) | Out-Null
          }    
        }
        return $DDArray
    }
    catch [System.Exception]{
        Write-Verbose "Exception getting the count of the data disks"
        Write-Verbose "Error in getting the count of the data disks: $($_.Exception.Message) "
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
		Stop-Transcript
		Exit $ERRORLEVEL
    }
}
    
function Get-AffinityGroupCount{
    
    try{
        
        Write-Verbose "Getting the number of affinity groups"
        $AffinityGroup = (Get-AzureAffinityGroup)
        $AffinityGroupCount = (Get-AzureAffinityGroup).Count
        $AffinityGroupArray = New-Object System.Collections.ArrayList
        Write-Verbose "$AffinityGroupCount"
        foreach($ag in $AffinityGroup){
          $AffinityGroupCountObject = New-Object PSObject -Property @{AffinityGroupCount = $AffinityGroupCount;
            Type = "AffinityGroup";
            AffinityGroupName = $ag.Name;
            AffinityGroupLocation = $ag.Location;
            AffinityGroupVirtualSizes = $ag.VirtualMachineRoleSizes;
            AffinityGroupWebWorkerRoleSizes = $ag.WebWorkerRoleSizes;
            AffinityGroupStorageServices = $ag.StorageServices; 
        }
         $AffinityGroupArray.Add($AffinityGroupCountObject) | Out-Null
        }
        
        return $AffinityGroupArray
    }
    catch [System.Exception]{
        Write-Verbose "Exception getting the count of the affinity group"
        Write-Verbose "Error in getting the count of the affinity groups: $($_.Exception.Message) "
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
		Stop-Transcript
		Exit $ERRORLEVEL
    }
}

function Get-StorageAccountCount{
    
    try{
        Write-Verbose "Getting the number of storage accounts."
        Set-AzureSubscription -SubscriptionId $SubscriptionId
        Select-AzureSubscription -SubscriptionID $SubscriptionId
        $StorageAccountCount = (Get-AzureStorageAccount).Count
        $StorageAccount = (Get-AzureStorageAccount)
        $StorageAccountArray = New-Object System.Collections.ArrayList
        
        foreach($sa in $StorageAccount){   
            Write-Verbose "$StorageAccountCount"
            $StorageAccountCountObject = New-Object PSObject -Property @{StorageAccountCount= $StorageAccountCount;
            Type = "StorageAccount";
            StorageAccountName = $sa.StorageAccountName;
            StorageAccountLocation = $sa.Location;
            StorageAccountGeoRepEnabled = $sa.GeoReplicationEnabled;
            StorageAccountAffinityGroup = $sa.AffinityGroup;
            }

            $StorageAccountArray.Add($StorageAccountCountObject) | Out-Null
        }
            
        return $StorageAccountArray
    }
    catch [System.Exception]{
        Write-Verbose "Exception getting the count of the storage accounts"
        Write-Verbose "Error in getting the count of the storage accounts: $($_.Exception.Message) "
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
		Stop-Transcript
		Exit $ERRORLEVEL
    }
}

function Get-StorageContainerCount{
    
    try{
        Write-Verbose "Getting the number of storage accounts."
        
        $ContainerArray = New-Object System.Collections.ArrayList
        #$SubscriptionName = (Get-AzureSubscription -SubscriptionId $SubscriptionID).SubscriptionName
        $StorageAccountCount = (Get-AzureStorageAccount)
        foreach($Object in $StorageAccountCount){
            Set-AzureSubscription -CurrentStorageAccountName $Object.StorageAccountName -SubscriptionId $SubscriptionID
            #Select-AzureSubscription -SubscriptionName $SubscriptionName
            $Count = (Get-AzureStorageContainer).Count
            $Container = Get-AzureStorageContainer
            foreach($Cont in $Container){
                
            $ContainerCount = New-Object PsObject -Property @{
                                Type = "Container";
                                CurrentStorageAccountName = $Object.StorageAccountName ;
                                ContainerCount = $Count;
                                ContainerName = $Cont.Name;
                                ContainerPermission = $Cont.Permission;
                                ContainerPublicAccess = $cont.PublicAccess;
                                }
            
            $ContainerArray.Add($ContainerCount)|Out-Null
          }
        }
        return $ContainerArray
    }
    catch [System.Exception]{
        Write-Verbose "Exception getting the count of the storage containers"
        Write-Verbose "Error in getting the count of the storage containers: $($_.Exception.Message) "
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
		Stop-Transcript
		Exit $ERRORLEVEL
    }
}

function Get-StorageBlobCount{
    
    try{
        Write-Verbose "Getting the number of storage accounts."
        
        $BlobArray = New-Object System.Collections.ArrayList
        
        #$SubscriptionName = (Get-AzureSubscription -Current).SubscriptionName
        $StorageAccountCount = (Get-AzureStorageAccount)
        foreach($Object in $StorageAccountCount){
            Set-AzureSubscription -CurrentStorageAccountName $Object.StorageAccountName -SubscriptionId $SubscriptionID
            #Select-AzureSubscription -SubscriptionName $SubscriptionName
            $Count = (Get-AzureStorageContainer)
            foreach($obj in $Count){
               $out= (Get-AzureStorageBlob -Container $obj.Name)
               foreach($blob in $out){
                   Write-Verbose "The name is $Object.StorageAccountName, container is $obj.Name and Blob count is $out."
                   $BlobCount = New-Object PSObject -Property @{CurrentStorageAccountName = $Object.StorageAccountName ; 
                                  ContainerName = $obj.Name ; 
                                  BlobCount = $out;
                                  BlobName = $blob.Name;
                                  BlobType = $blob.BlobType;
                                  BlobLength = $blob.Length;
                                  Type = "Blob";
                                  }
                   $BlobArray.Add($BlobCount) | Out-Null
              }
            }   
        }
        return $BlobArray
    }
    catch [System.Exception]{
        Write-Verbose "Exception getting the count of the storage blobs"
        Write-Verbose "Error in getting the count of the storage blobs: $($_.Exception.Message) "
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
		Stop-Transcript
		Exit $ERRORLEVEL
    }
}

function Get-AzureServiceCount{
    
    try{
        Write-Verbose "Getting the number of cloud services..."
        $Count = (Get-AzureService).Count
        $Service = Get-AzureService 
        $ServiceArray = New-Object System.Collections.ArrayList
        Write-Verbose "$ServiceCount"
        foreach($Serv in $Service){
            $ServiceCount =New-Object PSObject -Property @{ ServiceCount = $Count;
                               ServiceName = $Serv.ServiceName;
                               ServiceLocation = $Serv.Location;
                               ServiceAffinityGroup = $Serv.AffinityGroup;
                               ServiceStatus = $Serv.Status;
                               ServiceURL = $Serv.Url;
                               Type ="CloudService";
                             }
                   $ServiceArray.Add($ServiceCount) | Out-Null
          }
        return $ServiceArray
    }
    catch [System.Exception]{
        Write-Verbose "Exception getting the count of the cloud services"
        Write-Verbose "Error in getting the count of the cloud services: $($_.Exception.Message) "
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
		Stop-Transcript
		Exit $ERRORLEVEL
    }
}

function Get-AzureAutomationCount{
   
    try{
        Write-Verbose "Getting the number of automation accounts..."
        $AccountCount = (Get-AzureAutomationAccount)
        $Array = New-Object System.Collections.ArrayList
        foreach($obj in $AccountCount){
            $VariableCount = (Get-AzureAutomationVariable -AutomationAccountName $obj.AutomationAccountName).Count
            $CredCount = (Get-AzureAutomationCredential -AutomationAccountName $obj.AutomationAccountName).Count
            $CertificateCount = (Get-AzureAutomationCertificate -AutomationAccountName $obj.AutomationAccountName).Count
            $ConnCount = (Get-AzureAutomationConnection -AutomationAccountName $obj.AutomationAccountName).Count 
            $RunbookCount = (Get-AzureAutomationRunbook -AutomationAccountName $obj.AutomationAccountName).Count 
            $AccountArray = New-Object PSObject -Property @{Type= "AutomationAccount";AutomationAccountName = $obj.AutomationAccountName; VariableCount= $VariableCount; CredCount = $CredCount; CertificateCount = $CertificateCount; ConnectionCount = $ConnCount; RunbookCount = $RunbookCount}
    
            $Array.Add($AccountArray) | Out-Null

        }

        Write-Verbose "$AccountCount"
        return $Array
    }
    catch [System.Exception]{
        Write-Verbose "Exception getting the count."
        Write-Verbose "Error in getting the count.: $($_.Exception.Message) "
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
		Stop-Transcript
		Exit $ERRORLEVEL
    }
}

function Get-AzureNetworkCount{
    
    try{
        Write-Verbose "Getting the number of networks..."
        $TempNetworkConfig = Get-AzureVNetConfig
        if($TempNetworkConfig -eq $null){
            Write-Verbose "Error getting the network configuration." 
        }
        else{
            Write-Verbose "Successfully got the network configuration."
        }
        $NetworkConfig = [xml]$TempNetworkConfig.XMLConfiguration
        $Network=($NetworkConfig.NetworkConfiguration.VirtualNetworkConfiguration.VirtualNetworkSites.ChildNodes.Count)
        $NetworkCountObject = New-Object PSObject -Property @{Type="Network";NetworkCount= $Network;}
        return $NetworkCountObject
    }
    catch [System.Exception]{
        Write-Verbose "Exception getting the count of the networks"
        Write-Verbose "Error in getting the count of the networks: $($_.Exception.Message) "
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
		Stop-Transcript
		Exit $ERRORLEVEL
    }
}

function Get-AzureSubnetCount{
    
    try{
        Write-Verbose "Getting the number of subnet..."
        $TempNetworkConfig = Get-AzureVNetConfig
        if($TempNetworkConfig -eq $null){
            Write-Verbose "Error getting the network configuration." 
        }
        else{
            Write-Verbose "Successfully got the network configuration."
        }
        $SubnetArray = New-Object System.Collections.ArrayList
        $NetworkConfig = [xml]$TempNetworkConfig.XMLConfiguration
        $Network=($NetworkConfig.NetworkConfiguration.VirtualNetworkConfiguration.VirtualNetworkSites.ChildNodes)
        foreach($Net in $Network){
            $Count=($Net.Subnets.ChildNodes.Count)
            $SubnetCount = New-Object PSObject -Property @{NetworkName = $Net.name ; SubnetCount = $Count; Type = "Subnet";}
            Write-Verbose "For the ($Net.name), the number of subnets is: $Count "
            $SubnetArray.Add($SubnetCount) | Out-Null
        }
        return $SubnetArray
    }
    catch [System.Exception]{
        Write-Verbose "Exception getting the count of the networks"
        Write-Verbose "Error in getting the count of the networks: $($_.Exception.Message) "
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
		Stop-Transcript
		Exit $ERRORLEVEL
    }
}

function Get-AzureDNSServerCount{
    
    try{
        Write-Verbose "Getting the number of DNS Servers..."
        $TempNetworkConfig = Get-AzureVNetConfig
        if($TempNetworkConfig -eq $null){
            Write-Verbose "Error getting the network configuration." 
        }
        else{
            Write-Verbose "Successfully got the network configuration."
        }
        $NetworkConfig = [xml]$TempNetworkConfig.XMLConfiguration
        $DNSServerCount=($NetworkConfig.NetworkConfiguration.VirtualNetworkConfiguration.DNs.DnsServers.DnsServer.Count)
        Write-Verbose "$DNSServerCount"
        $DNSServerCountObject = New-Object PSObject -Property @{Type="DNSServer";DNSServerCount= $DNSServerCount;}
        return $DNSServerCountObject
    }
    catch [System.Exception]{
        Write-Verbose "Exception getting the count of the DNS Servers"
        Write-Verbose "Error in getting the count of the DNS Servers: $($_.Exception.Message) "
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
		Stop-Transcript
		Exit $ERRORLEVEL
    }
}

function Get-StorageQueueCount{
    
    try{
        Write-Verbose "Getting the number of storage accounts."
        
        $ContainerArray = New-Object System.Collections.ArrayList
        
        #$SubscriptionName = (Get-AzureSubscription -Current).SubscriptionName
        $StorageAccountCount = (Get-AzureStorageAccount)
        foreach($Object in $StorageAccountCount){
            Set-AzureSubscription -CurrentStorageAccountName $Object.StorageAccountName -SubscriptionId $SubscriptionID
            #Select-AzureSubscription -SubscriptionName $SubscriptionName
            $Count = (Get-AzureStorageQueue).Count
            $Queue = Get-AzureStorageQueue
            foreach($Q in $Queue){
               
            $ContainerCount =New-Object PsObject -Property @{Type = "Queue";
                                CurrentStorageAccountName = $Object.StorageAccountName ;
                                QueueCount = $Count;
                                QueueName = $Q.Name;
                                QueueUri = $Q.Uri;}
            
            Write-Verbose "For the $Object.StorageAccountName, the number of queues is: $Count "
            $ContainerArray.Add($ContainerCount)|Out-Null
          }
        }
        return $ContainerArray
    }
    catch [System.Exception]{
        Write-Verbose "Exception getting the count of the storage queues"
        Write-Verbose "Error in getting the count of the storage queues: $($_.Exception.Message) "
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
		Stop-Transcript
		Exit $ERRORLEVEL
    }
}

function Get-StorageTableCount{
    
    try{
        Write-Verbose "Getting the number of storage accounts."
        
        $TableArray = New-Object System.Collections.ArrayList
        
        #$SubscriptionName = (Get-AzureSubscription -Current).SubscriptionName
        $StorageAccountCount = (Get-AzureStorageAccount)
        foreach($Object in $StorageAccountCount){
            Set-AzureSubscription -CurrentStorageAccountName $Object.StorageAccountName -SubscriptionId $SubscriptionID
            #Select-AzureSubscription -SubscriptionName $SubscriptionName
            $Count = (Get-AzureStorageTable).Count
            $Table = Get-AzureStorageTable
            Foreach($tab in $Table){
  
                $TableCount = New-Object PsObject -Property @{CurrentStorageAccountName = $Object.StorageAccountName ;
                                TableCount = $Count;
                                TableName = $tab.Name;
                                TableUri = $tab.Uri;
                                Type="StorageTable";

                                }
            
                Write-Verbose "For the $Object.StorageAccountName, the number of tables is: $Count "
                $TableArray.Add($TableCount)|Out-Null
           }
        }
        return $TableArray
    }
    catch [System.Exception]{
        Write-Verbose "Exception getting the count of the storage tables"
        Write-Verbose "Error in getting the count of the storage tables: $($_.Exception.Message) "
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
		Stop-Transcript
		Exit $ERRORLEVEL
    }
}

function Get-OperationalInsightsInfo{

    try{
        
        Write-Verbose "Getting the number of Operational Insights Workspaces"
        $Workspaces = Get-AzureResource -ResourceType Microsoft.OperationalInsights/workspaces -ExpandProperties
        $WorkspacesCount = 0
        if($Workspaces -ne $null)
        {
            if($Workspaces.GetType().Name -eq "PSCustomObject")
            {
                $WorkspacesCount = 1
            }
            else
            {
                $WorkspacesCount = $Workspaces.Count
            }
        }
        $workspaceobject = $Workspaces.PsObject.Copy()
        $workspaceobject | Add-Member -MemberType NoteProperty -Name Count -Value $WorkspacesCount -Force
        $workspaceobject | Add-Member -MemberType NoteProperty -Name Type -Value "Operation Insights" -Force
        
        Write-Verbose "Number of workspaces : $WorkspacesCount"
        
        return $workspaceobject
    }
    catch [System.Exception]{
        Write-Verbose "Exception getting the Operational Insights workspaces"
        Write-Verbose "Error in getting the Operational Insights workspaces: $($_.Exception.Message) "
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
		Stop-Transcript
		Exit $ERRORLEVEL
    }
}

function Get-AlertsInfo{

    try{
        
        Write-Verbose "Getting the number of alerts set"
        $Alerts = Get-AzureResource -ResourceType microsoft.insights/alertrules -OutputObjectFormat New
        $AlertsCount = 0
        if($Alerts -ne $null)
        {
            if($Alerts.GetType().Name -eq "PSCustomObject")
            {
                $AlertsCount = 1
            }
            else
            {
                $AlertsCount = $Alerts.Count
            }
        }
        $AlertsArray = New-Object System.Collections.ArrayList
        Write-Verbose "Number of alerts : $AlertsCount"

        foreach($alert in $Alerts)
        {
            $alertobject = $alert.PsObject.Copy()
            $alertRule = Get-AlertRule -Name $alert.Name -ResourceGroup $alert.ResourceGroupName -DetailedOutput
            $alertobject | Add-Member -MemberType NoteProperty -Name ExtendedProperties -Value $alertRule.Properties
            $alertobject | Add-Member -MemberType NoteProperty -Name TotalAlertsCount -Value $AlertsCount 
            $alertobject | Add-Member -MemberType NoteProperty -Name Type -Value "Alerts" 
            $AlertsArray.Add($alertobject) | Out-Null
        }
        
        return $AlertsArray
    }
    catch [System.Exception]{
        Write-Verbose "Exception getting the alerts"
        Write-Verbose "Error in getting the alerts: $($_.Exception.Message) "
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
		Stop-Transcript
		Exit $ERRORLEVEL
    }
}

function Get-AllAzureResources{

    try{
        
        Write-Verbose "Getting the azure resources"

        $resources = Get-AzureResource -SubscriptionId $SubscriptionId -OutputObjectFormat New | Sort-Object -Property ResourceType
        $resourceTypes = $resources.ResourceType | Sort-Object -Unique
        $InventoryList = New-Object System.Collections.ArrayList

        foreach($resourceType in $resourceTypes)
        {
            $SingleTypeResource = $resources | Where-Object {$_.ResourceType -eq $resourceType}    
            $ResourceCount = 0
            if($SingleTypeResource -ne $null)
            {
                if($SingleTypeResource.GetType().Name -eq "PSCustomObject")
                {
                    $ResourceCount = 1
                }
                else
                {
                    $ResourceCount = $SingleTypeResource.Count
                }
            }
            $InventoryItem = @{Type = "Global Inventory";ResourceType = $resourceType.Split('/')[$resourceType.Split('/').Count-1]; ResourceCount = $ResourceCount; Details = $SingleTypeResource}
            $InventoryList.Add($InventoryItem) | Out-Null
        } 
        
        return $InventoryList
    }
    catch [System.Exception]{
        Write-Verbose "Exception getting the all the azure resources"
        Write-Verbose "Error in getting all the azure resources: $($_.Exception.Message) "
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
		Stop-Transcript
		Exit $ERRORLEVEL
    }
}


function Convert-OutputForCSV {
    
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipeline)]
        [psobject]$InputObject,
        [parameter()]
        [ValidateSet('Stack','Comma')]
        [string]$OutputPropertyType = 'Stack'
    )
    Begin {
        $PSBoundParameters.GetEnumerator() | ForEach {
            Write-Verbose "$($_)"
        }
        $FirstRun = $True
    }
    Process {
        If ($FirstRun) {
            $OutputOrder = $InputObject.psobject.properties.name
            Write-Verbose "Output Order:`n $($OutputOrder -join ', ' )"
            $FirstRun = $False
            #Get properties to process
            $Properties = Get-Member -InputObject $InputObject -MemberType *Property
            #Get properties that hold a collection
            $Properties_Collection = @(($Properties | Where-Object {
                $_.Definition -match "Collection|\[\]"
            }).Name)
            #Get properties that do not hold a collection
            $Properties_NoCollection = @(($Properties | Where-Object {
                $_.Definition -notmatch "Collection|\[\]"
            }).Name)
            Write-Verbose "Properties Found that have collections:`n $(($Properties_Collection) -join ', ')"
            Write-Verbose "Properties Found that have no collections:`n $(($Properties_NoCollection) -join ', ')"
        }
 
        $InputObject | ForEach {
            $Line = $_
            $stringBuilder = New-Object Text.StringBuilder
            $Null = $stringBuilder.AppendLine("[pscustomobject] @{")

            $OutputOrder | ForEach {
                If ($OutputPropertyType -eq 'Stack') {
                    $Null = $stringBuilder.AppendLine("`"$($_)`" = `"$(($line.$($_) | Out-String).Trim())`"")
                } ElseIf ($OutputPropertyType -eq "Comma") {
                    $Null = $stringBuilder.AppendLine("`"$($_)`" = `"$($line.$($_) -join ', ')`"")                   
                }
            }
            $Null = $stringBuilder.AppendLine("}")
 
            Invoke-Expression $stringBuilder.ToString()
        }
    }
    End {}
}

Function Release-Ref ($ref) 
{
        ([System.Runtime.InteropServices.Marshal]::ReleaseComObject(
        [System.__ComObject]$ref) -gt 0)
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers() 
    }

Function ConvertCSV-ToExcel
{
<#   
  .SYNOPSIS  
    Converts one or more CSV files into an excel file.
     
  .DESCRIPTION  
    Converts one or more CSV files into an excel file. Each CSV file is imported into its own worksheet with the name of the
    file being the name of the worksheet.
       
  .PARAMETER inputfile
    Name of the CSV file being converted
  
  .PARAMETER output
    Name of the converted excel file
       
  .EXAMPLE  
  Get-ChildItem *.csv | ConvertCSV-ToExcel -output 'report.xlsx'
  
  .EXAMPLE  
  ConvertCSV-ToExcel -inputfile 'file.csv' -output 'report.xlsx'
    
  .EXAMPLE      
  ConvertCSV-ToExcel -inputfile @("test1.csv","test2.csv") -output 'report.xlsx'
  
  .NOTES
  Author: Boe Prox									      
  Date Created: 01SEPT210								      
  Last Modified:  
     
#>
     
#Requires -version 2.0  
[CmdletBinding(
    SupportsShouldProcess = $True,
    ConfirmImpact = 'low',
	DefaultParameterSetName = 'file'
    )]
Param (    
    [Parameter(
     ValueFromPipeline=$True,
     Position=0,
     Mandatory=$True,
     HelpMessage="Name of CSV/s to import")]
     [ValidateNotNullOrEmpty()]
    [array]$inputfile,
    [Parameter(
     ValueFromPipeline=$False,
     Position=1,
     Mandatory=$True,
     HelpMessage="Name of excel file output")]
     [ValidateNotNullOrEmpty()]
    [string]$output    
    )

Begin {     
    #Configure regular expression to match full path of each file
    [regex]$regex = "^\w\:\\"
    
    #Find the number of CSVs being imported
    $count = ($inputfile.count -1)
   
    #Create Excel Com Object
    $excel = new-object -com excel.application
    
    #Disable alerts
    $excel.DisplayAlerts = $False

    #Show Excel application
    $excel.Visible = $False

    #Add workbook
    $workbook = $excel.workbooks.Add()

    <#
    #Remove other worksheets
    $workbook.worksheets.Item(0).delete()
    #After the first worksheet is removed,the next one takes its place
    $workbook.worksheets.Item(2).delete()   
    #>

    #Define initial worksheet number
    $i = 1
    }

Process {
    ForEach ($input in $inputfile) {
        #If more than one file, create another worksheet for each file
        If ($i -gt 1) {
            $workbook.worksheets.Add() | Out-Null
            }
        #Use the first worksheet in the workbook (also the newest created worksheet is always 1)
        $worksheet = $workbook.worksheets.Item(1)
        #Add name of CSV as worksheet name
        $worksheet.name = "$((GCI $input).basename)"

        #Open the CSV file in Excel, must be converted into complete path if no already done
        If ($regex.ismatch($input)) {
            $tempcsv = $excel.Workbooks.Open($input) 
            }
        ElseIf ($regex.ismatch("$($input.fullname)")) {
            $tempcsv = $excel.Workbooks.Open("$($input.fullname)") 
            }    
        Else {    
            $tempcsv = $excel.Workbooks.Open("$($pwd)\$input")      
            }
        $tempsheet = $tempcsv.Worksheets.Item(1)
        #Copy contents of the CSV file
        $tempSheet.UsedRange.Copy() | Out-Null
        #Paste contents of CSV into existing workbook
        $worksheet.Paste()

        #Close temp workbook
        $tempcsv.close()

        #Select all used cells
        $range = $worksheet.UsedRange

        #Autofit the columns
        $range.EntireColumn.Autofit() | out-null
        $i++
        } 
    }        

End {
    #Save spreadsheet
    $workbook.saveas("$pwd\$output")

    Write-Host -Fore Green "File saved to $pwd\$output"

    #Close Excel
    $excel.quit()  

    #Release processes for Excel
    $a = Release-Ref($range)
    }
}        



#endregion

#region - Script Control Routine
#region - Transcript Error Trap
try { stop-transcript | out-null }
catch [System.InvalidOperationException]{ }
#endregion

#This code prevents the Write-Debug from asking for confirmation
If ($PSBoundParameters['Debug']) {
    $DebugPreference = 'Continue'
}

Start-Transcript $ScriptLog
Write-Verbose "======================================================================"
Write-Verbose "Script Started."

if(Get-IsElevated)
{
    try
    {
        # Insert code for elevated execution
		(Get-Host).UI.RawUI.WindowTitle = "$env:USERDOMAIN\$env:USERNAME (Elevated)"
		Write-Verbose "Script is running in an elevated PowerShell host. "
        
        Add-AzureAccount -Verbose
        Select-AzureSubscription -SubscriptionId $SubscriptionID -Default 
        Set-AzureSubscription -SubscriptionId $SubscriptionID -Verbose 
        
        $ArrayOfCustomObjects = New-Object System.Collections.ArrayList
        Switch-AzureMode -Name AzureResourceManager | Out-Null

        $result = $null
        $result = Get-AllAzureResources
        $ArrayOfCustomObjects.Add($result)|Out-Null
        
        $result = $null
        $result = Get-OperationalInsightsInfo
        $ArrayOfCustomObjects.Add($result)|Out-Null

        $result = $null
        $result = Get-AlertsInfo
        $ArrayOfCustomObjects.Add($result)|Out-Null
        
        Switch-AzureMode -Name AzureServiceManagement | Out-Null

        $result = $null
        $result = Get-AzureAutomationCount
        $ArrayOfCustomObjects.Add($result)|Out-Null

        $result = $null
        $result = Get-StorageContainerCount
        $ArrayOfCustomObjects.Add($result)|Out-Null
        
        $result = $null
        $result = Get-StorageBlobCount
        $ArrayOfCustomObjects.Add($result)|Out-Null

        $result = $null
        $result = Get-AffinityGroupCount
        $ArrayOfCustomObjects.Add($result)|Out-Null

        $result = $null
        $result = Get-StorageQueueCount
        $ArrayOfCustomObjects.Add($result)|Out-Null

        $result = $null
        $result = Get-StorageTableCount
        $ArrayOfCustomObjects.Add($result)|Out-Null

        $result = $null
        $result = Get-VMCount
        $ArrayOfCustomObjects.Add($result)|Out-Null

        $result = $null
        $result = Get-OSDataDisk
        $ArrayOfCustomObjects.Add($result)|Out-Null

        $result = $null
        $result = Get-AzureSubnetCount
        $ArrayOfCustomObjects.Add($result)|Out-Null

        $result = $null
        $result = Get-AzureServiceCount
        $ArrayOfCustomObjects.Add($result)|Out-Null

        $result = $null
        $result = Get-AzureNetworkCount
        $ArrayOfCustomObjects.Add($result)|Out-Null

        $result = $null
        $result = Get-AzureDNSServerCount
        $ArrayOfCustomObjects.Add($result)|Out-Null
       

        if(Test-Path -Path $FolderPath)
        {
            $FDPath =  "$FolderPath\InventoryReport" + "$(get-date -f MM-dd-yyyy_HH_mm_ss)"
            mkdir -Path $FDPath
        }
        
        foreach($obj in $ArrayOfCustomObjects){
        if($obj -ne $null){
            $CSVname = $obj.Type | Sort-Object -Unique | Select-Object
            Write-Output "Making the file"
            Write-Output "$obj"
            $obj | Convert-OutputForCSV | Export-Csv -Path "$FDPath\$CSVName.csv" -Force            

        }
        else{
            Write-Output "$obj is empty."
        }
        }

        cd $FDPath
        Get-ChildItem *.csv | ConvertCSV-ToExcel -output ("InventoryReport_"+"$(get-date -f MM-dd-yyyy_HH_mm_ss).xlsx")
  
        Write-Verbose "The inventory has been completed. "
		       
    }
    catch [system.exception]
	{
		Write-Verbose "Script Error: $($_.Exception.Message) "
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
		Stop-Transcript
		Exit $ERRORLEVEL
	}
}
else
{
	# Insert code for non-elevated execution
	(Get-Host).UI.RawUI.WindowTitle = "$env:USERDOMAIN\$env:USERNAME (Not Elevated)"
	Write-Verbose "Please start the script from an elevated PowerShell host. "
	Stop-Transcript
	Exit $ERRORLEVEL
}
Write-Verbose "Script Completed. "
Write-Verbose "======================================================================"
Stop-Transcript
#endregion