param(
  
  $username = "mydomain\azureuser",
  $Password = "Password@12345",
  [String]$Broker = "Broker.Mydomain.local"

) # /param  


Enable-WSManCredSSP -Role Client -DelegateComputer * -Force
$Cred = New-Object System.Management.Automation.PSCredential -ArgumentList @($username,(ConvertTo-SecureString -String $password -AsPlainText -Force))

$vmsessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck
$Session01 = new-PSSession -ComputerName "138.91.248.126" -Credential $Cred -UseSSL -SessionOption $vmsessionOption -Authentication Credssp


Invoke-Command -Session $Session01 -ScriptBlock { param($Broker)

Write-Output $Broker
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

# Extract of the information Ends here

Write-Output "`n RD server : "$RDS_RD_Server
Write-Output "`n RDS_WEB_ACCESS : "$RDS_WEB_ACCESS

} -ArgumentList $Broker # end of Invoke command Script Block  


Get-PSSession | Remove-PSSession -Verbose




