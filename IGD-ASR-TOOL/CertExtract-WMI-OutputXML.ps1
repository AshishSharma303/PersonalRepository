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

$IsElevated = Get-IsElevated 
$IsElevated 

function CertExtract ($ComputerName)
{
    $Error.Clear();
    $CertGroupArray = New-Object System.Collections.ArrayList
    foreach ($ComputerItem in $ComputerName)
    {
    try
        {
            [String]$ComputerNameStr = "\\" + $ComputerName + "\my"
            $store=new-object System.Security.Cryptography.X509Certificates.X509Store($ComputerNameStr,”LocalMachine”)
        }
        catch [System.Exception]
        {
            Write-Verbose "Exception occured in getting the details of Certificates from remote computer"
            Write-Verbose "Error Details are: "
            Write-Verbose $Error[0].ToString()
            LogToEventLog -EventMessage $Error[0].ToString() -EntryType Error
        }
        $store.open(“ReadOnly”)
        $store.certificates | % {
            $GroupObject = New-Object PSObject -Property @{
                            ComputerName = $ComputerName;
                            Subject = $_.Subject;
                            Issuer = $_.Issuer;
                            NotBefore  = $_.NotBefore;
                            NotAfter = $_.NotAfter;
                            Extensions = $_.Extensions;
                            PSComputerName  = $_.PSComputerName;
                            FriendlyName =  $_.FriendlyName;
                            Thumbprint = $_.Thumbprint;
                            DnsNameList = $_.DnsNameList;
                            EnhancedKeyUsageList = $_.EnhancedKeyUsageList;
                            }
            $CertGroupArray.Add($GroupObject) | Out-Null
            }
    
    }

    return $CertGroupArray
} # end of function.

$ServerCollection = New-Object System.Collections.ArrayList
# Dumy Input
$ServerCollection = @("ashishT460")
#Building XML object and putting the format for XML Writer.
$xmlWriter = New-Object -TypeName System.XMl.XmlTextWriter  ('C:\Users\ashis\Documents\GitHub\IGD-ASR-TOOL\certExtract-XMLoutput.xml',$Null)
$xmlWriter.Formatting = 'Indented'
$xmlWriter.Indentation = 1
$XmlWriter.IndentChar = "`t"
$xmlWriter.WriteStartDocument()
 # set XSL statements
$xmlWriter.WriteProcessingInstruction("xml-stylesheet", "type='text/xsl' href='style.xsl'")
$xmlWriter.WriteComment('XML output for ASR failover machines.')
# create "root" element
$xmlWriter.WriteStartElement('Root')
foreach ($Server in $ServerCollection)
{
    Write-Host "Extrating results for $($Server) : "
    $certExtractResult = CertExtract -ComputerName $Server
    $certExtractResult
    $xmlWriter.WriteStartElement('ServerName')
    $xmlWriter.WriteStartElement('CertExtract')
        foreach ($Certitem in $certExtractResult)
        {
        Write-Output $Certitem
            foreach ($item in $Certitem)
            {
                $result  = $item | Get-Member | select name 
                ForEach($RS in $result)
                #$result | foreach 
                {
                     Write-Host "Value of name:" $RS.Name
                    $ItemValue = $RS.name.toString()
                     Write-Host "Value of Poperty Value: "  $item."$ItemValue"
                    # $_Name:  will provide the property name of PS Object, $Item."$ItemValue" will provide the value of the PSObject.
                    $xmlWriter.WriteElementString($RS.name, $item."$ItemValue")
                }
            }
        #$itemCollection.Add($Certitem)
    }

    
    #End the CertItem Element
    $xmlWriter.WriteEndElement()
    # End of ServerName Element
    $xmlWriter.WriteEndElement()
}



# End of the Root Element
$xmlWriter.WriteEndElement()
# close the document, flush whatever is in the internal buffer and close the stream to the file releasing control.
$xmlWriter.WriteEndDocument()
$xmlWriter.Flush()
$xmlWriter.Close()

