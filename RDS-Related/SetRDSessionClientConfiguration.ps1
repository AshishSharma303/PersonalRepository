
<#
.SYNOPSIS
  Connects to Azure RDS setup and collectes information of RDS Collections in the specified Azure subscription or resource group

.DESCRIPTION
  This runbook connects to Azure and collects information of RDS Collections in the specified Azure subscription or resource group.  
  Parameters to be filled to set settings for the RDS client side configurations.
.Optional  
  You can attach a schedule to this runbook to run it at a specific time. 
.Parameters
[String]$broker
[String]$collectionName
[Parameter(Mandatory = $true,HelpMessage="Allowed Values: AudioVideoPlayBack,AudioRecording,SmartCard,PlugAndPlayDevice,Drive,Clipboard,COMPort,LPTPort")]
[String]$ClientDeviceRedirectionOptions
[Parameter(Mandatory = $False,HelpMessage="Allowed Values: True, False")]
[String]$ClientPrinterRedirected
[Parameter(Mandatory = $False,HelpMessage="Allowed Values: True, False")]
[String]$ClientPrinterAsDefault
[Parameter(Mandatory = $False,HelpMessage="Allowed Values: True, False")]
[String]$RDEasyPrintDriverEnabled
[String]$Password
[String]$Username
   
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
[Parameter(Mandatory = $true,HelpMessage="Allowed Values: AudioVideoPlayBack,AudioRecording,SmartCard,PlugAndPlayDevice,Drive,Clipboard,COMPort,LPTPort")]
[String]$ClientDeviceRedirectionOptions = "AudioVideoPlayBack,AudioRecording,SmartCard,PlugAndPlayDevice,Drive,Clipboard,COMPort,LPTPort",
[Parameter(Mandatory = $False,HelpMessage="Allowed Values: True, False")]
[ValidateSet("True","False")]
[String]$ClientPrinterRedirected = "True",
[Parameter(Mandatory = $False,HelpMessage="Allowed Values: True, False")]
[ValidateSet("True","False")]
[String]$ClientPrinterAsDefault = "True",
[Parameter(Mandatory = $False,HelpMessage="Allowed Values: True, False")]
[ValidateSet("True","False")]
[String]$RDEasyPrintDriverEnabled = "True",

 
[Parameter(Mandatory = $True)]
[String]$Password = "Password@12345",
[Parameter(Mandatory = $True)]
[String]$Username = "Mydomain\azureuser"


) # Param section close.  

# checking if the RDS tools are already installed on local Machine.
$localMachine = $env:COMPUTERNAME
$RDSToolCheck = Get-WindowsFeature -Name "RSAT-RDS-Tools" -ComputerName $localMachine
if ($RDSToolCheck.InstallState -ne "Installed")
{
        Install-WindowsFeature RSAT-RDS-Gateway,RSAT-RDS-Tools,RDS-Licensing-UI,RSAT-RDS-Licensing-Diagnosis-UI -Verbose
}
else{ Write-Output "`n RDS Tools are installed on localMachine $($localMachine)" }

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
[String]$ClientDeviceRedirectionOptions,
[String]$ClientPrinterRedirected,
[String]$ClientPrinterAsDefault,
[String]$RDEasyPrintDriverEnabled
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
           $ClientDeviceRedirectionOptions = $ClientDeviceRedirectionOptions.ToLower()

           if ($ClientDeviceRedirectionOptions -ne "None")
           {
               try 
               { 
                    Write-Output "ClientDeviceRedirectionOptions " $ClientDeviceRedirectionOptions                  
                    If ($ClientDeviceRedirectionOptions.Contains("audiovideoplayback"))
                    {
                        $CmdtoExecute = "AudioVideoPlayBack"
                    }
                    Else
                    {
                        $CmdtoExecute = "NothingToUpdate"
                    }
                    If ($ClientDeviceRedirectionOptions.Contains("audiorecording"))
                    {
                        $CmdtoExecute = $CmdtoExecute + ",audiorecording"
                    }
                    If ($ClientDeviceRedirectionOptions.contains("smartcard"))
                    {
                        $CmdtoExecute = $CmdtoExecute + ",smartcard"
                        
                    }
                    If ($ClientDeviceRedirectionOptions.Contains("plugandplaydevice"))
                    {
                        $CmdtoExecute = $CmdtoExecute + ",plugandalaydevice"
                    }
                    If ($ClientDeviceRedirectionOptions.Contains("drive"))
                    {
                        $CmdtoExecute = $CmdtoExecute + ",drive"
                    }
                    If ($ClientDeviceRedirectionOptions.Contains("dlipboard"))
                    {
                        $CmdtoExecute = $CmdtoExecute + ",clipboard"
                    }
                    If ($ClientDeviceRedirectionOptions.Contains("comport"))
                    {
                        $CmdtoExecute = $CmdtoExecute + ",comport"
                    }
                    If ($ClientDeviceRedirectionOptions.Contains("lptport"))
                    {
                        $CmdtoExecute = $CmdtoExecute + ",lptport"
                    }
                    
                    if ($CmdtoExecute.Contains("NothingToUpdate,"))
                    {
                        $CmdtoExecute = $CmdtoExecute.Replace("NothingToUpdate,","")
                    }

                    if ($CmdtoExecute -ne "NothingToUpdate")
                    {
                       Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -ClientDeviceRedirectionOptions $CmdtoExecute
                       Write-Output "`n setting ClientDeviceRedirectionOptions updated sucessfully, details below: "
                       Get-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -Client | select CollectionName,ClientDeviceRedirectionoptions
                    }
                    
                    
               }
               catch [system.Exception]
               {
                   Write-Output "`n setting ClientDeviceRedirectionOptions had an error, details below: "
                   Write-Output $Error[0]
               }
           }
           else
           {
               try
               { 
                    Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -ClientDeviceRedirectionOptions None
                    Write-Output "`n setting ClientDeviceRedirectionOptions updated sucessfully to None, details below: "
                    Get-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -Client | select CollectionName,ClientDeviceRedirectionoptions
               }
               Catch [System.Exception]
               {
                   Write-Output "`n setting ClientDeviceRedirectionoptions had an error, details below: "
                   Write-Output $Error[0]
               }
               
           }
           #  ClientDeviceRedirectionoptions ends here
           
           if ($ClientPrinterRedirected -eq "True")
           {
             try
               { 
                    Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -ClientPrinterRedirected $true -ErrorAction Continue
                    if ($ClientPrinterAsDefault -eq "True")
                    {
                        Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -ClientPrinterAsDefault $true -ErrorAction Continue
                        if ($RDEasyPrintDriverEnabled -eq "True")
                        {
                            Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -RDEasyPrintDriverEnabled $true
                        }
                        else
                        {
                            Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -RDEasyPrintDriverEnabled $true
                        }
                    }
                    if ($ClientPrinterAsDefault -eq "False")
                    {
                        Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -ClientPrinterAsDefault $False -ClientPrinterRedirected $False -RDEasyPrintDriverEnabled $False -ErrorAction Continue
                    }

                    Write-Output "`n setting ClientPrinterRedirected updated sucessfully to None, details below: "
                    Get-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -Client
               }
               Catch [System.Exception]
               {
                   Write-Output "`n setting ClientDeviceRedirectionoptions had an error, details below: "
                   Write-Output $Error[0]
               }  
           }
           else
           {
               try
               { 
                    Set-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -ClientPrinterRedirected $False
                    Write-Output "`n setting ClientPrinterRedirected updated sucessfully to None, details below: "
                    Get-RDSessionCollectionConfiguration -CollectionName $collectionName -ConnectionBroker $broker -Client
               }
               Catch [System.Exception]
               {
                   Write-Output "`n setting ClientDeviceRedirectionoptions had an error, details below: "
                   Write-Output $Error[0]
               }  
           }
           # Printer Redirection code ends here.
           
       
        
        
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



} -ArgumentList $Broker,$collectionName,$ClientDeviceRedirectionOptions,$ClientPrinterRedirected,$ClientPrinterAsDefault,$RDEasyPrintDriverEnabled
# Invoke module section Ends here

Get-PSSession | Remove-PSSession
