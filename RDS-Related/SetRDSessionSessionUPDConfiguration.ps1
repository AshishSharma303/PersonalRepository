

<#
.SYNOPSIS
  Connects to Azure RDS setup and collectes information of RDS Collections in the specified Azure subscription or resource group

.DESCRIPTION
  This runbook connects to Azure and collectes information of RDS Collections in the specified Azure subscription or resource group.  
  Parameters to be filled to set settings for the RDS collection configurations.
.Optional  
  You can attach a schedule to this runbook to run it at a specific time. 
.Parameters
    broker,
    collectionName,
    DisableUserProfileDisk ="False",
    MaxUserProfileDiskSizeGB,
    DiskPath,
    DisconnectedSessionLimitMin = 0,
    ActiveSessionLimitMin = 0,
    IdleSessionLimitMin = 0,
    AutomaticReconnectionEnabled = "False",
    BrokenConnectionAction = "None",
    Action
   
.NOTES
   AUTHOR: CSP Team, Ashish Sharma 
   LASTEDIT: May 30, 2016
#>

Param
(
[Parameter(Mandatory = $true)]
[ValidateNotNullOrEmpty()]
[String]$broker = "Broker.mydomain.local",
[Parameter(Mandatory = $true)]
[ValidateNotNullOrEmpty()]
[String]$collectionName = "Desktop Collection",
[Parameter(Mandatory = $False)]
[ValidateNotNullOrEmpty()]
[ValidateSet("True","False")]
[String]$DisableUserProfileDisk ="False",
[Parameter(Mandatory = $False)]
[ValidateNotNullOrEmpty()]
[int]$MaxUserProfileDiskSizeGB,
[Parameter(Mandatory = $False)]
[ValidateNotNullOrEmpty()]
[String]$DiskPath,
[Parameter(Mandatory = $False)]
[ValidateNotNullOrEmpty()]
[Int]$DisconnectedSessionLimitMin = 0,
[Parameter(Mandatory = $False)]
[ValidateNotNullOrEmpty()]
[Int]$ActiveSessionLimitMin = 0,
[Parameter(Mandatory = $False)]
[ValidateNotNullOrEmpty()]
[Int]$IdleSessionLimitMin = 0,
[Parameter(Mandatory = $False)]
[ValidateSet("True", "False")]
[String]$AutomaticReconnectionEnabled = "FALSE",
[Parameter(Mandatory = $False)]
[ValidateSet("None","Disconnect","LogOff")]
[String]$BrokenConnectionAction = "None",
[Parameter(Mandatory = $False)]
[ValidateSet("True", "False")]
[String]$TemporaryFoldersDeletedOnExit = "true",
[Parameter(Mandatory = $False)]
[ValidateSet("True", "False")]
[String]$TemporaryFoldersPerSession = "true",


[Parameter(Mandatory = $True)]
[String]$Password = "Password@12345",
[Parameter(Mandatory = $True)]
[String]$Username = "Mydomain\azureuser",
[Parameter(Mandatory = $False)]
[ValidateSet("remove")]
[String]$Action

) # Param section close.  

[String]$AutomaticReconnectionEnabled = $AutomaticReconnectionEnabled.ToLower()
[String]$BrokenConnectionAction = $BrokenConnectionAction.ToLower()
[String]$DiskPath = $DiskPath.ToLower()
[String]$DisableUserProfileDisk = $DisableUserProfileDisk.ToLower()
[String]$TemporaryFoldersDeletedOnExit = $TemporaryFoldersDeletedOnExit.ToLower()
[String]$TemporaryFoldersPerSession = $TemporaryFoldersPerSession.ToLower()


# checking if the RDS tools are already installed on local Machine.
$localMachine = $env:COMPUTERNAME
$RDSToolCheck = Get-WindowsFeature -Name "RSAT-RDS-Tools" -ComputerName $localMachine
if ($RDSToolCheck.InstallState -ne "Installed")
{
        Install-WindowsFeature RSAT-RDS-Gateway,RSAT-RDS-Tools,RDS-Licensing-UI,RSAT-RDS-Licensing-Diagnosis-UI -Verbose
}
else{ Write-Output "Tools are already installed on localMachine $($localMachine)" }

$getRDSModudle = Get-Module -Name RemoteDesktop -ErrorAction SilentlyContinue
If($getRDSModudle){Write-Output "Remotedesktop Module is present on local Machine $($localMachine) `n"}Else{ Import-Module RemoteDesktop -ErrorAction SilentlyContinue }

# Building PSS Session
$Cred = New-Object System.Management.Automation.PSCredential -ArgumentList @($username,(ConvertTo-SecureString -String $password -AsPlainText -Force))
$vmsessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck
$Session01 = new-PSSession -ComputerName $localMachine -Credential $Cred -UseSSL -SessionOption $vmsessionOption -Authentication Credssp



# Invoke module section Starts

Invoke-Command -Session $Session01 -ScriptBlock {
Param
(
[String]$broker,
[String]$collectionName,
[String]$DisableUserProfileDisk,
[int]$MaxUserProfileDiskSizeGB,
[String]$DiskPath,
[Int]$DisconnectedSessionLimitMin,
[Int]$ActiveSessionLimitMin,
[Int]$IdleSessionLimitMin,
[String]$AutomaticReconnectionEnabled,
[String]$BrokenConnectionAction,
[String]$TemporaryFoldersDeletedOnExit,
[String]$TemporaryFoldersPerSession,
[String]$Action
) # Param section close.  

$getRDSModudle = Get-Module -Name RemoteDesktop -ErrorAction SilentlyContinue
If($getRDSModudle){Write-Output "Remotedesktop Module is present on local Machine $($localMachine) `n"}Else{ Import-Module RemoteDesktop -ErrorAction SilentlyContinue }

$getRdServer = Get-RDServer -ConnectionBroker $Broker
If($getRdServer) {}else{Write-Output "The Remote Desktop Management service is not running on the RD Connection Broker server `n you might not provided the correct Broker server input or local machine has not the RDS tools configured." }

function RoleCheck ($RoleValue)
{
    $ServerRole = New-Object System.Collections.ArrayList
    foreach ($Server in $getRdServer)
    {
        $role = $null
        foreach ($role in $Server.Roles)
        {
            If($role -contains $RoleValue)
            {
                $Server = $server.Server
                if ($Server)
                {
                   $ServerRole.Add($Server) | Out-Null
                }
                
            }
        }
    }
return $ServerRole
}

$RDS_RD_Server = RoleCheck -RoleValue "RDS-RD-SERVER"
$RDS_WEB_ACCESS = RoleCheck -RoleValue "RDS-WEB-ACCESS"
$RDS_CONNECTION_BROKER = RoleCheck -RoleValue "RDS-CONNECTION-BROKER"
$RDS_GATEWAY = RoleCheck -RoleValue "RDS-GATEWAY"
$RDS_LICENSING = RoleCheck -RoleValue "RDS-LICENSING"

# Getting Session Collection information
$getRdsSessionCollection = Get-RDSessionCollection -ConnectionBroker "Broker.mydomain.local"
if ($getRdsSessionCollection)
{
    $CollectionArray = New-Object System.Collections.ArrayList
    foreach ($Collection in $getRdsSessionCollection)
    {
        try
        {
            $GetUserGroup = Get-RDSessionCollectionConfiguration -CollectionName $Collection.CollectionName -UserGroup -ConnectionBroker $RDS_CONNECTION_BROKER -ErrorAction SilentlyContinue
            $GetConnection = Get-RDSessionCollectionConfiguration -CollectionName $Collection.CollectionName -Connection -ConnectionBroker $RDS_CONNECTION_BROKER -ErrorAction SilentlyContinue
            $GetUserProfileDisk = Get-RDSessionCollectionConfiguration -CollectionName $Collection.CollectionName -UserProfileDisk -ConnectionBroker $RDS_CONNECTION_BROKER -ErrorAction SilentlyContinue
            $GetLoadbalancing = Get-RDSessionCollectionConfiguration -CollectionName $Collection.CollectionName -LoadBalancing -ConnectionBroker $RDS_CONNECTION_BROKER -ErrorAction SilentlyContinue
            $GetClient = Get-RDSessionCollectionConfiguration -CollectionName $Collection.CollectionName -Client -ConnectionBroker $RDS_CONNECTION_BROKER -ErrorAction SilentlyContinue
            $GetSecurity = Get-RDSessionCollectionConfiguration -CollectionName $Collection.CollectionName -Security -ConnectionBroker $RDS_CONNECTION_BROKER -ErrorAction SilentlyContinue

            $CollectionGroup = New-Object PSObject -Property @{
            CollectionName = $Collection.CollectionName;
            Collection_ResourceType = $Collection.ResourceType;
            Collection_Size = $Collection.Size;
            Collection_Alias = $Collection.CollectionAlias;
            Collection_UserGroup = $GetUserGroup.UserGroup;
            Connection_DisconnectedSessionLimitMin = $GetConnection.DisconnectedSessionLimitMin;
            Connection_ActiveSessionLimitMin = $GetConnection.ActiveSessionLimitMin;
            Connection_IdleSessionLimitMin = $GetConnection.IdleSessionLimitMin;
            Connection_TemporaryFoldersDeletedOnExit = $GetConnection.TemporaryFoldersDeletedOnExit;
            Connection_AutomaticReconnectionEnabled = $GetConnection.AutomaticReconnectionEnabled;
            UserProfileDisk_DiskPath = $GetUserProfileDisk.DiskPath;
            UserProfileDisk_EnableUserProfileDisk = $GetUserProfileDisk.EnableUserProfileDisk;
            UserProfileDisk_MaxUserProfileDiskSizeGB = $GetUserProfileDisk.MaxUserProfileDiskSizeGB;
            LoadBalancing_SessionLimit = $GetLoadbalancing.SessionLimit;
            LoadBalancing_SessionHost = $GetLoadbalancing.SessionHost;
            Client_MaxRedirectedMonitors = $GetClient.MaxRedirectedMonitors;
            Client_ClientDeviceRedirectionOptions = $GetClient.ClientDeviceRedirectionOptions;
            Security_AuthenticateUsingNLA = $GetSecurity.AuthenticateUsingNLA;
            Security_EncryptionLevel = $GetSecurity.EncryptionLevel;
            Security_SecurityLayer = $GetSecurity.SecurityLayer;

            } # end of PSObject
        }
        catch [System.Exception]
        {
            Write-Verbose $Error[0].ToString()
        }

        $CollectionArray.Add($CollectionGroup) | Out-Null
    }
}
# Collection Array Finish.


if ($RDS_CONNECTION_BROKER -contains $Broker)
     {
        Write-Output "`n $($Broker), Broker name provided is valid."
        $CollectionCheck = Get-RDSessionCollection -CollectionName $collectionName -ConnectionBroker $Broker
        If($CollectionCheck)
        {
           Write-Output "`n $($collectionName), Collection name provided is valid."
           if ($DisableUserProfileDisk -eq "True")
           {
               try 
               { 
                    Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -DisableUserProfileDisk -ErrorAction Continue
                    Write-Output "`n setting DisableUserProfileDisk updated sucessfully, details below: "
                    Get-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -UserProfileDisk
               }
               catch [system.Exception]
               {
                   Write-Output "`n setting DisableUserProfileDisk had an error, details below: "
                   Write-Output $Error[0]
               }
               
               
           }
           else
           {
               try
               { 
                    Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -EnableUserProfileDisk -MaxUserProfileDiskSizeGB $MaxUserProfileDiskSizeGB -DiskPath $DiskPath -ErrorAction Continue 
                    Write-Output "`n setting EnableUserProfileDisk updated sucessfully, details below: "
                    Get-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -UserProfileDisk
               }
               Catch [System.Exception]
               {
                   Write-Output "`n setting EnableUserProfileDisk had an error, details below: "
                   Write-Output $Error[0]
               }
               
           }
           #  DisableUserProfileDisk or EnableUserProfileDisk ends here
           
		   if (($DisconnectedSessionLimitMin -gt 0) -or ($ActiveSessionLimitMin -gt 0) -or ($IdleSessionLimitMin -gt 0))
           {
                Try
                {
                    Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -DisconnectedSessionLimitMin $DisconnectedSessionLimitMin -ActiveSessionLimitMin $ActiveSessionLimitMin -IdleSessionLimitMin $IdleSessionLimitMin -ErrorAction Continue
                    Write-Output "`n setting SessionLimit updated sucessfully, details below: "
                    Get-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -Connection | select CollectionName, DisconnectedSessionLimitMin, ActiveSessionLimitMin, IdleSessionLimitMin
                }
                Catch [System.Exception]
                {
                    Write-Output "`n setting SessionLimit for collection had an error, details below: "
                    Write-Output $Error[0]
                }    
           }
           # End for setting SessionLimit for collection 

           if ($AutomaticReconnectionEnabled -eq "true")
           {
                Try
                {
                    Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -AutomaticReconnectionEnabled $True -ErrorAction Continue
                    Write-Output "setting AutomaticReconnectionEnabled to the collection, details below: "
                    Get-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -Connection | select CollectionName, AutomaticReconnectionEnabled
                }
                Catch [System.Exception]
                {
                    Write-Output "`n setting AutomaticReconnectionEnabled for collection had an error, details below: "
                    Write-Output $Error[0]
                }    
           }
           elseif($AutomaticReconnectionEnabled -eq "false")
           {
                Try
                {
                    Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -AutomaticReconnectionEnabled $False -ErrorAction Continue
                    Write-Output "setting AutomaticReconnectionEnabled to the collection, details below: "
                    Get-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -Connection | select CollectionName, AutomaticReconnectionEnabled
                }
                Catch [System.Exception]
                {
                    Write-Output "`n setting AutomaticReconnectionEnabled for collection had an error, details below: "
                    Write-Output $Error[0]
                } 
           
           }
           
           # End for setting AutomaticReconnectionEnabled for collection 
           
           if ($BrokenConnectionAction -eq "none")
           {
                Try
                {
                    Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -BrokenConnectionAction $BrokenConnectionAction -ErrorAction Continue
                    Write-Output "setting BrokenConnectionAction to the collection, details below: "
                    Get-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -Connection | select CollectionName, BrokenConnectionAction 
                }
                Catch [System.Exception]
                {
                    Write-Output "`n setting BrokenConnectionAction for collection had an error, details below: "
                    Write-Output $Error[0]
                }    
           }
           Elseif(($BrokenConnectionAction -eq "disconnect") -or ($BrokenConnectionAction -eq "logoff"))
           {
                Try
                {
                    Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -BrokenConnectionAction $BrokenConnectionAction -ErrorAction Continue
                    Write-Output "setting BrokenConnectionAction to the collection, details below: "
                    Get-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -Connection | select CollectionName, BrokenConnectionAction 
                }
                Catch [System.Exception]
                {
                    Write-Output "`n setting BrokenConnectionAction for collection had an error, details below: "
                    Write-Output $Error[0]
                }
           
           }
           # End for setting BrokenConnectionAction for collection 
           
           if ($TemporaryFoldersDeletedOnExit -eq "true")
           {
                Try
                {
                    Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -TemporaryFoldersDeletedOnExit $True -ErrorAction Continue
                    Write-Output "setting TemporaryFoldersDeletedOnExit to the collection, details below: "
                    Get-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -Connection | select CollectionName, TemporaryFoldersDeletedOnExit
                }
                Catch [System.Exception]
                {
                    Write-Output "`n setting TemporaryFoldersDeletedOnExit for collection had an error, details below: "
                    Write-Output $Error[0]
                }    
           }
           elseif($TemporaryFoldersDeletedOnExit  -eq "false")
           {
                Try
                {
                    Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -TemporaryFoldersDeletedOnExit $False -ErrorAction Continue
                    Write-Output "setting TemporaryFoldersDeletedOnExit to the collection, details below: "
                    Get-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -Connection | select CollectionName, TemporaryFoldersDeletedOnExit
                }
                Catch [System.Exception]
                {
                    Write-Output "`n setting TemporaryFoldersDeletedOnExit for collection had an error, details below: "
                    Write-Output $Error[0]
                } 
           
           }
           
           # End for setting TemporaryFoldersDeletedOnExit for collection
           

           if ($TemporaryFoldersPerSession -eq "true")
           {
                Try
                {
                    Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -TemporaryFoldersPerSession $True -ErrorAction Continue
                    Write-Output "setting TemporaryFoldersPerSession to the collection, details below: "
                    Get-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -Connection | select CollectionName, TemporaryFoldersPerSession
                }
                Catch [System.Exception]
                {
                    Write-Output "`n setting TemporaryFoldersPerSession for collection had an error, details below: "
                    Write-Output $Error[0]
                }    
           }
           elseif($TemporaryFoldersPerSession -eq "false")
           {
                Try
                {
                    Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -TemporaryFoldersPerSession $False -ErrorAction Continue
                    Write-Output "setting TemporaryFoldersPerSession to the collection, details below: "
                    Get-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -Connection | select CollectionName, TemporaryFoldersPerSession
                }
                Catch [System.Exception]
                {
                    Write-Output "`n setting TemporaryFoldersPerSession  for collection had an error, details below: "
                    Write-Output $Error[0]
                } 
           
           }
           
           # End for setting TemporaryFoldersPerSession for collection




        
        
        } # If End for CollectionCheck true
        Else
        {
           Write-Output "`n Not able to find the Collection $($collectionName)" 
        }
     }
     else
     {
        Write-Output "`n $($Broker), is not mentioned in the list of current RDS deployment.."
     }



} -ArgumentList $Broker,$collectionName,$DisableUserProfileDisk,$MaxUserProfileDiskSizeGB,$DiskPath,$DisconnectedSessionLimitMin,$ActiveSessionLimitMin,$IdleSessionLimitMin,$AutomaticReconnectionEnabled,$BrokenConnectionAction,$Action,$TemporaryFoldersPerSession,$TemporaryFoldersDeletedOnExit
# Invoke module section Ends here


Get-PSSession | Remove-PSSession