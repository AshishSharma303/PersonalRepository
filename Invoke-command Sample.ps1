param(
  
  $username = "mydomain\azureuser",
  $Password = "Password@12345",
  $ServiceName = "WSService"
) # /param  


$Cred = New-Object System.Management.Automation.PSCredential -ArgumentList @($username,(ConvertTo-SecureString -String $password -AsPlainText -Force))

$vmsessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck
$Session01 = new-PSSession -ComputerName "138.91.242.111" -Credential $Cred -UseSSL -SessionOption $vmsessionOption



Invoke-Command -Session $Session01 -ScriptBlock {param($ServiceName)

Stop-Service $ServiceName
Add-WindowsFeature -Name Rsat-rds-tools,telnet-client


} -ArgumentList $ServiceName # end of Script Block  







