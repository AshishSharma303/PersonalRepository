[String]$Broker = "Broker.Mydomain.local"


$getRdServer = Get-RDServer -ConnectionBroker $Broker

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




             









