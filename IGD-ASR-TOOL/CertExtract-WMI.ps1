
<#
function LogToEventLog($HashInfo,$EventMessage, $EntryType)
{
    if ($EntryType = "EventHashInformation")
    {
            $EventHashInfo = @{
            LogName   = 'LiftAndShiftLog'
            Source    = 'scripts'
            EventId   = 30101
            EntryType = 'Information'
        }
    }

    if ($EntryType = "EventHashWarning")
    {
        $EventHashInfo = @{
        LogName   = "LiftAndShiftLog"
        Source    = "scripts"
        EventId   = 40101
        EntryType = "Warning" 
        }
    }
    if ($EntryType = "EventHashError")
    {
        $EventHashInfo = @{
        LogName   = "LiftAndShiftLog"
        Source    = "scripts"
        EventId   = 50101
        EntryType = "Error"  
        }
    }
     
    #Check for Event Log.
    $getEventLog = Get-EventLog -LogName "LiftAndShiftLog" -ErrorAction SilentlyContinue
    if ($getEventLog)

    {
        #Write-Host "Event Log LiftAndShiftLog is present"
        Write-EventLog -LogName LiftAndShiftLog -Source scripts -Message $EventMessage -EventId 50101 -EntryType $EntryType
        # Write-EventLog @EventHashInfo -Message $EventMessage
    }
    else
    {
         Write-Host "Event Log LiftAndShiftLog is not present"
         New-EventLog -LogName "LiftAndShiftLog" -Source Scripts
         Limit-EventLog -LogName  "LiftAndShiftLog" -OverflowAction OverwriteOlder -RetentionDays 1 -Maximum 20MB
         Write-EventLog -LogName LiftAndShiftLog -Source scripts -Message “EventLog for Lift And Shift created” -EventId 50001 -EntryType information
         Write-EventLog -LogName LiftAndShiftLog -Source scripts -Message $EventMessage -EventId 50101 -EntryType $EntryType
    }

}

# LogToEventLog $Global:EventHashInformation -EventMessage $Error[0]
LogToEventLog -HashInfo "EventHashInformation" -EventMessage $Error[0]

#>

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


$certExtractResult = CertExtract -ComputerName "ashishT460"
$certExtractResult
ConvertTo-Json -InputObject $certExtractResult | Out-File C:\Users\ashis\Documents\GitHub\IGD-ASR-TOOL\certExtract-JSONFile.json
