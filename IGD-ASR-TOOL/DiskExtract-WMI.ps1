

Function Get-RemoteDiskInformation
{
    <#
    .SYNOPSIS
       Get inventory data for specified computer systems.
    .DESCRIPTION
       Gather inventory data for one or more systems using wmi. Data proccessing utilizes multiple runspaces
       and supports custom timeout parameters in case of wmi problems. You can optionally include 
       drive, memory, and network information in the results. You can view verbose information on each 
       runspace thread in realtime with the -Verbose option.
    .PARAMETER ComputerName
       Specifies the target computer for data query.
    #>
    [CmdletBinding()]
    PARAM
    (
        [string[]]   $ComputerName    
    )


          Filter ConvertTo-KMG 
                {
                     <#
                     .Synopsis
                      Converts byte counts to Byte\KB\MB\GB\TB\PB format
                     .DESCRIPTION
                      Accepts an [int64] byte count, and converts to Byte\KB\MB\GB\TB\PB format
                      with decimal precision of 2
                     .EXAMPLE
                     3000 | convertto-kmg
                     #>

                     $bytecount = $_
                        switch ([math]::truncate([math]::log($bytecount,1024))) 
                        {
                            0 {"$bytecount Bytes"}
                            1 {"{0:n2} KB" -f ($bytecount / 1kb)}
                            2 {"{0:n2} MB" -f ($bytecount / 1mb)}
                            3 {"{0:n2} GB" -f ($bytecount / 1gb)}
                            4 {"{0:n2} TB" -f ($bytecount / 1tb)}
                            Default {"{0:n2} PB" -f ($bytecount / 1pb)}
                        }
                }


               $VMPremiumdiskusage =@()
               $Global:VMPremiumdiskMountpointsusage =@() 
                  
                # WMI data
                # $ComputerName = "gateway"
                $wmi_diskdrives = Get-WmiObject -Class Win32_DiskDrive -ComputerName $ComputerName 
                $wmi_mountpoints = Get-WmiObject  -ComputerName $ComputerName -Class Win32_Volume -Filter "DriveType=3 AND DriveLetter IS NULL" | Select $WMI_DiskMountProps
                
                $AllDisks = @()
                $DiskElements = @('ComputerName','Disk','Model','Partition','Description','PrimaryPartition','VolumeName','Drive','DiskSize','FreeSpace','UsedSpace','PercentFree','PercentUsed','DiskType','SerialNumber')
                foreach ($diskdrive in $wmi_diskdrives) 
                {
                    $partitionquery = "ASSOCIATORS OF {Win32_DiskDrive.DeviceID=`"$($diskdrive.DeviceID.replace('\','\\'))`"} WHERE AssocClass = Win32_DiskDriveToDiskPartition"
                    $partitions = @(Get-WmiObject -ComputerName $ComputerName -Query $partitionquery)
                    foreach ($partition in $partitions)
                    {
                        $logicaldiskquery = "ASSOCIATORS OF {Win32_DiskPartition.DeviceID=`"$($partition.DeviceID)`"} WHERE AssocClass = Win32_LogicalDiskToPartition"
                        $logicaldisks = @(Get-WmiObject -ComputerName $ComputerName -Query $logicaldiskquery)
                        foreach ($logicaldisk in $logicaldisks)
                        {
                            $PercentFree = [math]::round((($logicaldisk.FreeSpace/$logicaldisk.Size)*100), 2)
                            $UsedSpace = ($logicaldisk.Size - $logicaldisk.FreeSpace)
                            $diskprops = @{
                                           ComputerName = $ComputerName
                                           Disk = $diskdrive.Name
                                           Model = $diskdrive.Model
                                           Partition = $partition.Name
                                           Description = $partition.Description
                                           PrimaryPartition = $partition.PrimaryPartition
                                           VolumeName = $logicaldisk.VolumeName
                                           Drive = $logicaldisk.Name
                                           DiskSize = if ($RawDriveData) { $logicaldisk.Size } else { $logicaldisk.Size | ConvertTo-KMG }
                                           FreeSpace = if ($RawDriveData) { $logicaldisk.FreeSpace } else { $logicaldisk.FreeSpace | ConvertTo-KMG }
                                           UsedSpace = if ($RawDriveData) { $UsedSpace } else { $UsedSpace | ConvertTo-KMG }
                                           PercentFree = $PercentFree
                                           PercentUsed = [math]::round((100 - $PercentFree),2)
                                           DiskType = 'Partition'
                                           SerialNumber = $diskdrive.SerialNumber
                                         }
                                $VMPremiumdiskusage += New-Object psobject -Property $diskprops | Select $DiskElements
                                Write-Host $VMPremiumdiskusage
                        }
                    }
                }
            # Mountpoints are weird so we do them seperate.
                if ($wmi_mountpoints)
                {
                    foreach ($mountpoint in $wmi_mountpoints)
                    {
                        $PercentFree = [math]::round((($mountpoint.FreeSpace/$mountpoint.Capacity)*100), 2)
                        $UsedSpace = ($mountpoint.Capacity - $mountpoint.FreeSpace)
                        $diskprops = @{
                               ComputerName = $ComputerName
                               Disk = $mountpoint.Name
                               Model = ''
                               Partition = ''
                               Description = $mountpoint.Caption
                               PrimaryPartition = ''
                               VolumeName = ''
                               VolumeSerialNumber = ''
                               Drive = [Regex]::Match($mountpoint.Caption, "(^.:)").Value
                               DiskSize = if ($RawDriveData) { $mountpoint.Capacity } else {} # $mountpoint.Capacity | ConvertTo-KMG }
                               FreeSpace = if ($RawDriveData) { $mountpoint.FreeSpace } else { } #$mountpoint.FreeSpace | ConvertTo-KMG }
                               UsedSpace = if ($RawDriveData) { $UsedSpace } else { } #$UsedSpace | ConvertTo-KMG }
                               PercentFree = $PercentFree
                               PercentUsed = [math]::round((100 - $PercentFree),2)
                               DiskType = 'MountPoint'
                               SerialNumber = $mountpoint.SerialNumber
                             }
                        $VMPremiumdiskMountpointsusage += New-Object psobject -Property $diskprops  | Select $DiskElements
                        write-host $VMPremiumdiskMountpointsusage
                    }
                }

           
           return $VMPremiumdiskusage 

           #$Global:VMPremiumdiskMountpointsusage
 
       
       } 

$remoteDiskInformation = Get-RemoteDiskInformation -ComputerName "ashishT460" -Verbose
$remoteDiskInformation 


