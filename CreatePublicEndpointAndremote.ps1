function Configure-AzureWinRMHTTPS {
  <#
  .SYNOPSIS
  Configure WinRM over HTTPS inside an Azure VM.
  .DESCRIPTION
  1. Creates a self signed certificate on the Azure VM.
  2. Creates and executes a custom script extension to enable Win RM over HTTPS and opens 5986 in the Windows Firewall
  3. Creates a Network Security Rules for the Network Security Group attached the the first NIC attached the the VM allowing inbound traffic on port 5986
  .EXAMPLE
   Configure-AzureWinRMHTTPS -ResourceGroupName "TestGroup" -VMName "TestVM"
  .EXAMPLE
  Give another example of how to use it
  .PARAMETER ResourceGroupName
  Name of the resource group that the VM exists in
  .PARAMETER VMName
  The name of the virtual machine you wish to enable Win RM on.
   .PARAMETER DNSName
  DNS name you will use to connect to the VM. If not provided defaults to the computer name.
  .PARAMETER SourceAddressPrefix
  Provide an CIDR value to restrict connections to a specific IP range
  
  Command to check the winRm Configuration 
  winrm e winrm/config/listener  

  #>
 
   
  Param
          (
            [parameter(Mandatory=$true)]
            [String]
            $VMName,
             
            [parameter(Mandatory=$true)]
            [String]
            $ResourceGroupName,      
 
            [parameter()]
            [String]
            $DNSName = $env:COMPUTERNAME,
              
            [parameter()]
            [String]
            $SourceAddressPrefix = "*"
 
          ) 
 
# define a temporary file in the users TEMP directory
$file = $env:TEMP + "\ConfigureWinRM_HTTPS.ps1"
  
#Create the file containing the PowerShell
 
{
   
# POWERSHELL TO EXECUTE ON REMOTE SERVER BEGINS HERE
 
param($DNSName)
 
# Ensure PS remoting is enabled, although this is enabled by default for Azure VMs
Enable-PSRemoting -Force
  
# Create rule in Windows Firewall
New-NetFirewallRule -Name "WinRM HTTPS" -DisplayName "WinRM HTTPS" -Enabled True -Profile Any -Action Allow -Direction Inbound -LocalPort 5986 -Protocol TCP
  
# Create Self Signed certificate and store thumbprint
$thumbprint = (New-SelfSignedCertificate -DnsName $DNSName -CertStoreLocation Cert:\LocalMachine\My).Thumbprint
  
# Run WinRM configuration on command line. DNS name set to computer hostname, you may wish to use a FQDN
$cmd = "winrm create winrm/config/Listener?Address=*+Transport=HTTPS @{Hostname=""$DNSName""; CertificateThumbprint=""$thumbprint""}"
cmd.exe /C $cmd
  
# POWERSHELL TO EXECUTE ON REMOTE SERVER ENDS HERE
  
}  | out-file $file -force
 
$VMName = "gw-vm"
$ResourceGroupName = "rdsdeploybasic201"
  
# Get the VM we need to configure
$vm = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName
 
# Get storage account name
$storageaccountname = $vm.StorageProfile.OsDisk.Vhd.Uri.Split('.')[0].Replace('https://','')
  
# get storage account key
$key = (Get-AzureRmStorageAccountKey -Name $storageaccountname -ResourceGroupName $ResourceGroupName).Key1
  
# create storage context
$storagecontext = New-AzureStorageContext -StorageAccountName $storageaccountname -StorageAccountKey $key
  
# create a container called scripts
New-AzureStorageContainer -Name "scripts" -Context $storagecontext
  
#upload the file
Set-AzureStorageBlobContent -Container "scripts" -File $file -Blob "ConfigureWinRM_HTTPS.ps1" -Context $storagecontext -force
 
# Create custom script extension from uploaded file
Set-AzureRmVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Name "EnableWinRM_HTTPS" -Location $vm.Location -StorageAccountName $storageaccountname -StorageAccountKey $key -FileName "ConfigureWinRM_HTTPS.ps1" -ContainerName "scripts" -RunFile "ConfigureWinRM_HTTPS.ps1" -Argument $DNSName
  
# Get the name of the first NIC in the VM
$nic = Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName -Name (Get-AzureRmResource -ResourceId $vm.NetworkInterfaceIDs[0]).ResourceName
 
# Get the network security group attached to the NIC
$nsg = Get-AzureRmNetworkSecurityGroup  -ResourceGroupName $ResourceGroupName  -Name (Get-AzureRmResource -ResourceId $nic.NetworkSecurityGroup.Id).Name 
  
# Add the new NSG rule, and update the NSG
$nsg | Add-AzureRmNetworkSecurityRuleConfig -Name "WinRM_HTTPS" -Priority 1100 -Protocol TCP -Access Allow -SourceAddressPrefix $SourceAddressPrefix -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 5986 -Direction Inbound   | Set-AzureRmNetworkSecurityGroup
 
# get the NIC public IP
$ip = Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName -Name (Get-AzureRmResource -ResourceId $nic.IpConfigurations[0].PublicIpAddress.Id).ResourceName 
 
 
Write-Host "To connect to the VM using the IP address while bypassing certificate checks use the following command:" -ForegroundColor Green
Write-Host "Enter-PSSession -ComputerName " $ip.IpAddress  " -Credential <admin_username> -UseSSL -SessionOption (New-PsSessionOption -SkipCACheck -SkipCNCheck)" -ForegroundColor Green
 
}
