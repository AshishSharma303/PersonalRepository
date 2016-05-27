
[String]$Broker = "Broker.Mydomain.local"

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


# Adds one or more RD Session Host servers to a session collection 
function RdsNewRDSessionCollection($Broker, $SessionHost, $collectionName)
{
    #$Broker = "broker.mydomain.local"
    #$SessionHost = "RDSH-0.mydomain.local"
    #$collectionName = "RemoteDesktopCollection03"
    if ($RDS_CONNECTION_BROKER -contains $Broker)
    {
       if (($SessionHost -eq $null) -and ($collectionName -eq $null))
       {
           Write-Output "Session Host information is blank or not valid."
       }
       else
       {
           try
           {
               if ($RDS_RD_Server -contains $SessionHost)
               {
                   Write-Output "Server: $($SessionHost) has already RDS-RD-Server Role Insalled and might be added to a exisiting collection."
               }
               else
               {
                   Write-Output "Server has not RDS-RD-Server Role Insalled. `n executing Add-RdServer for $($SessionHost) `n"
                   $Add_RDSessionHost = Add-RDServer -Server $SessionHost -Role RDS-RD-SERVER -ConnectionBroker $Broker
                   If($Add_RDSessionHost)
                   {
                        #Check for existing collection exist
                        $CollectionCheck = Get-RDSessionCollection -CollectionName $collectionName -ConnectionBroker $Broker
                        If($CollectionCheck)
                        {
                            Write-Output "`n Collection $($collectionName) already exist in RDS deployment and will try to join $($SessionHost) the existing collection"
                            Set-RDSessionHost -SessionHost $SessionHost -NewConnectionAllowed Yes -ConnectionBroker $Broker -ErrorAction SilentlyContinue
                            $Add_RDSessionHost = Add-RDSessionHost -SessionHost $SessionHost -ConnectionBroker $Broker -CollectionName $collectionName
                            If($Add_RDSessionHost)
                            { Write-Output "`n Success: RD Session Host server added to a session collection successfully!! ` 
                              details below: `n Collection name : $($collectionName) `n Session Host: $($SessionHost) `n"  }
                        }
                        else
                        {
                            $NewCollection = New-RDSessionCollection -CollectionName $collectionName -CollectionDescription $collectionName -ConnectionBroker $Broker `
                            -SessionHost $SessionHost
                            If($NewCollection)
                            { Write-Output " `n Success: collection was deployed successfully!! details below: `n Collection name : $($collectionName) `n Session Host: $($SessionHost) `n"  }
                        }
                        
                   }
               
               }
               
               
           } #end of try
           catch [System.Exception]
           {
               Write-Output " `n adding $($SessionHost) had an error: `n $Error[0] "
           }



       }
    } #End of If $RDS_CONNECTION_BROKER -contains $Broker
    else
    {
        Write-Output "`n $($Broker), is not mentioned in the list of current RDS deployment.."
    }
}

# NewRDSessionCollection -Broker "broker.mydomain.local" -SessionHost "RDSH-0.mydomain.local" -collectionName "RemoteDesktopCollection03"



function RdsRemoveCollection
{

Param
(
[Parameter(Mandatory = $true)]
[ValidateNotNullOrEmpty()]
[String]$broker,
[Parameter(Mandatory = $true)]
[ValidateNotNullOrEmpty()]
[String]$collectionName,
[Parameter(Mandatory = $true)]
[ValidateSet("remove")]
[String]$Action

)    
     if ($RDS_CONNECTION_BROKER -contains $Broker)
     {
        Write-Output "`n $($Broker), Broker name provided is valid."
        $CollectionCheck = Get-RDSessionCollection -CollectionName $collectionName -ConnectionBroker $Broker
        If($CollectionCheck)
        {
             Write-Output "`n $($collectionName), Collection name provided is valid."
             <# If($Action -eq "add")
             {
                $NewCollection = New-RDSessionCollection -CollectionName $collectionName -CollectionDescription $collectionName -ConnectionBroker $Broker -Verbose -ErrorAction Stop
                If($NewCollection)
                { Write-Output " `n Success: collection was deployed successfully!! details below: `n Collection name : $($collectionName) `n"  }
             }
             #>
             If($Action -eq "remove")
             {
                # $collectionName = "DesktopCollection01"
                # $broker = "Broker.mydomain.local"
                Remove-RDSessionCollection -CollectionName $collectionName -ConnectionBroker $Broker -Force
                $GetCollection = Get-RDSessionCollection -CollectionName $collectionName -ConnectionBroker $Broker -ErrorAction SilentlyContinue
                If(!$GetCollection)
                    {Write-Output " `n Success: collection was removed successfully!! details below: `n Collection name : $($collectionName) `n"}
             }
        }
        Else
        {
           Write-Output "`n Not able to find the Collection $($collectionName)" 
        }
     }
     else
     {
        Write-Output "`n $($Broker), is not mentioned in the list of current RDS deployment.."
     }
      
}

 RemoveCollection -Broker "broker.mydomain.local" -collectionName "DesktopCollection01" -Action remove
          

function RdsUserGroup
{
Param
(
[Parameter(Mandatory = $true)]
[ValidateNotNullOrEmpty()]
[String]$broker,
[Parameter(Mandatory = $true)]
[ValidateNotNullOrEmpty()]
[String]$collectionName,
[Parameter(Mandatory = $true)]
[ValidateSet("add","remove")]
[String]$Action,
[Parameter(Mandatory = $true)]
[String]$UserGroup

)      
    $Error.Clear()
    if ($RDS_CONNECTION_BROKER -contains $Broker)
     {
        Write-Output "`n $($Broker), Broker name provided is valid."
        $CollectionCheck = Get-RDSessionCollection -CollectionName $collectionName -ConnectionBroker $Broker
        If($CollectionCheck)
        {
             Write-Output "`n $($collectionName), Collection name provided is valid."
             
             If($Action -eq "add")
             {
                # $collectionName = "DesktopCollection01"
                # $broker = "Broker.mydomain.local"
                # $userGroup = "Mydomain\Domain users"
                $GetUserGroup = Get-RDSessionCollectionConfiguration -CollectionName $collectionName -UserGroup -ConnectionBroker $broker -ErrorAction SilentlyContinue
                $UserGroupArray = New-Object System.Collections.ArrayList
                $UserGroupArray.Add($GetUserGroup.UserGroup) | Out-Null
                $UserGroupArray.Add($UserGroup) | Out-Null
                try
                {
                    $setRDSessionCollectionConfiguration = Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -UserGroup $UserGroupArray -ErrorAction Stop
                    $GetUserGroup = Get-RDSessionCollectionConfiguration -CollectionName $collectionName -UserGroup -ConnectionBroker $broker -ErrorAction SilentlyContinue
                    If($GetUserGroup.UserGroup -contains $UserGroup)
                    {Write-Output "Success : $($UserGroup) got successfully added to Usergroup property of collecion $($collectionName), details below: `n UserGroup: $($UserGroup) `n Collection name: $($collectionName)"}
                
                }
                catch [System.Exception]
                {
                    Write-Output "`n Error: while adding a Usergroup $($UserGroup) for collection $($collectionName) `n $Error[0]"
                }

        } # end of If ($Action -eq Add)
        Else
        {
           Write-Output "`n Not able to find the Collection $($collectionName) in current deployment." 
        }
     }
     else
     {
        Write-Output "`n $($Broker), Broker server is not mentioned in the list of current RDS deployment.."
     }

}


RdsUserGroup -broker "broker.mydomain.local" -collectionName "desktopcollection01" -Action add -UserGroup "Mydomain\Rds-Group"




