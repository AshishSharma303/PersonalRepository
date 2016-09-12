function CertExtract ([String]$ServerName)
{
    $Error.Clear();
    try
    {
        #remoting server to extract server information.
        $Certs = Invoke-Command -Computername $ServerName -Scriptblock {Get-ChildItem "Cert:\LocalMachine\My"}
    }
    catch [System.Exception]
    {
        Write-Verbose "Exception occured in getting the details of Certificates from remote computer"
        Write-Verbose "Error Details are: "
        Write-Verbose $Error[0].ToString()
    }

    
    $CertGroupArray = New-Object System.Collections.ArrayList
        foreach ($item in $Certs)
        {
            #Adding a group object for the each server.
            $GroupObject = New-Object PSObject -Property @{
                    Name = $item.PSComputerName;
                    Subject = $item.Subject;
                    Issuer = $item.Issuer;
                    NotBefore  = $item.NotBefore;
                    NotAfter = $item.NotAfter;
                    Extensions = $item.Extensions;
                    PSComputerName  = $item.PSComputerName;
                    FriendlyName =  $item.FriendlyName;
                    Thumbprint = $item.Thumbprint;
                    DnsNameList = $item.DnsNameList;
                    }
        # Adding the Item to Array with all Certs group information.
        $CertGroupArray.Add($GroupObject) | Out-Null
        }
        return $CertGroupArray
}

$CertExtractResult =  CertExtract -ServerName "ashishT460"





$store=new-object System.Security.Cryptography.X509Certificates.X509Store(“\\ashishT460\my”,”LocalMachine”)
$store.open(“ReadOnly”)
$store.certificates | % {
$GroupObject = New-Object PSObject -Property @{
                    Name = $_.PSComputerName;
                    Subject = $item.Subject;
                    Issuer = $item.Issuer;
                    NotBefore  = $item.NotBefore;
                    NotAfter = $item.NotAfter;
                    Extensions = $item.Extensions;
                    PSComputerName  = $item.PSComputerName;
                    FriendlyName =  $item.FriendlyName;
                    Thumbprint = $item.Thumbprint;
                    DnsNameList = $item.DnsNameList;
                    }
}


