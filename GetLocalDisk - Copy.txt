

$getDisk = New-Object System.Collections.ArrayList
$getDiskType3 = New-Object System.Collections.ArrayList
$getDisk = Get-WMIObject Win32_LogicalDisk
$I = 0;

function getDiskdetails()
{
   foreach ($item in $getDisk)
{
    
    if (($item.DriveType -eq 3) -and ($item.DeviceID -ne "D:"))
    {
        #Write-Host "Drive type 3 : \n " + $($item)
        $VMGroupObject = New-Object PSObject -Property @{
        DeviceID = $item.DeviceID  
        DriveType = $item.DriveType
        ProviderName = $item.ProviderName
        FreeSpace = [math]::truncate($item.FreeSpace / 1GB)
        Size = [math]::truncate($item.Size / 1GB)
        VolumeName = $item.VolumeName
                                                }
        #Write-Host "Psobject" + $VMGroupObject
    $getDiskType3.Add($VMGroupObject)
   
    }
    else
    {
        
    }

}
   return $getDiskType3
 
}


$outputCode =New-Object System.Collections.ArrayList
$outputCode = $null
$outputCode = getDiskdetails
foreach ($item in $outputCode)
{
    Write-Host $item | FT
}

