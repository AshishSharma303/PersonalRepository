# Parameters
param (
    [Parameter(Mandatory = $true)] 
    $ResourcegroupName,

    [Parameter(Mandatory = $true)] 
    $DetailsFilePath,

    [ValidateSet("StartBlobCopy", "MonitorBlobCopy")]
    [Parameter(Mandatory = $true)] 
    $StartType,

    $RefreshInterval = 10
)

# Load blob copy details file (ex: copyblobdetails.json)
$copyblobdetails = Get-Content -Path $DetailsFilePath -Raw | ConvertFrom-Json
$copyblobdetailsout = @()


# If Initiating the copy of all blobs
If ($StartType -eq "StartBlobCopy")
{
    # Initiate the copy of all blobs
    foreach ($copyblobdetail in $copyblobdetails)
    {
        $source_context = New-AzureStorageContext -StorageAccountName $copyblobdetail.SourceSA -StorageAccountKey $copyblobdetail.SourceKey
    
        $storageaccountkeys = Get-AzureRmStorageAccount -ResourceGroupName $resourcegroupname -Name $copyblobdetail.DestinationSA | Get-AzureRmStorageAccountKey
        if ($StorageAccountKeys.Key1 -eq $null)
        {
            $copyblobdetail.DestinationKey = $storageaccountkeys.Value[0]
        }
        else
        {
            $copyblobdetail.DestinationKey = $StorageAccountKeys.Key1
        }
        $destination_context = New-AzureStorageContext -StorageAccountName $copyblobdetail.DestinationSA -StorageAccountKey $copyblobdetail.DestinationKey

        # Create destination container if it does not exist
        $destination_container = Get-AzureStorageContainer -Context $destination_context -Name $copyblobdetail.DestinationContainer -ErrorAction SilentlyContinue
        if ($destination_container.count -eq 0)
        {
            New-AzureStorageContainer -Context $destination_context -Name $copyblobdetail.DestinationContainer
        }
   
        # Initiate blob copy job
        Start-CopyAzureStorageBlob -Context $source_context -SrcContainer $copyblobdetail.SourceContainer -SrcBlob $copyblobdetail.SourceBlob -DestContext $destination_context -DestContainer $copyblobdetail.DestinationContainer -DestBlob $copyblobdetail.DestinationBlob -Verbose
        $copyblobdetail.StartTime = Get-Date -Format u
        $copyblobdetailsout += $copyblobdetail
        cls
        $copyblobdetails | select DestinationSA, DestinationContainer, DestinationBlob, Status, BytesCopied, TotalBytes, StartTime, EndTime | Format-Table -AutoSize
    }

    $copyblobdetailsout | ConvertTo-Json -Depth 100 | Out-File $DetailsFilePath
}

# If waiting for all blobs to copy and get statistics
If ($StartType -eq "MonitorBlobCopy")
{
    # Waits for all blobs to copy and get statistics
    $continue = $true
    while ($continue)
    {
        $continue = $false
        foreach ($copyblobdetail in $copyblobdetails)
        {
            if ($copyblobdetail.Status -ne "Success" -and $copyblobdetail.Status -ne "Failed")
            {
                $destination_context = New-AzureStorageContext -StorageAccountName $copyblobdetail.DestinationSA -StorageAccountKey $copyblobdetail.DestinationKey
                $status = Get-AzureStorageBlobCopyState -Context $destination_context -Container $copyblobdetail.DestinationContainer -Blob $copyblobdetail.DestinationBlob

                $copyblobdetail.TotalBytes = "{0:N0} MB" -f ($status.TotalBytes / 1MB)
                $copyblobdetail.BytesCopied = "{0:N0} MB" -f ($status.BytesCopied / 1MB)
                $copyblobdetail.Status = $status.Status
                $copyblobdetail.EndTime = Get-Date -Format u

                $continue = $true
            }
        }

        $copyblobdetails | ConvertTo-Json -Depth 100 | Out-File $DetailsFilePath
        cls
        $copyblobdetails | select DestinationSA, DestinationContainer, DestinationBlob, Status, BytesCopied, TotalBytes, StartTime, EndTime | Format-Table -AutoSize

        Start-Sleep -Seconds $refreshinterval
    }
}