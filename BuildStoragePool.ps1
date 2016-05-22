Configuration ConfigureVM
{
  param ($MachineName)

  Node $MachineName
  {
	Script ConfigureVM { 
		SetScript = { 
			$dir = "c:\Source"
            $FileURI = "https://github.com/AZITCAMP/Labfiles/raw/master/lab02/iometer.zip"
            New-Item $dir -ItemType directory
            $output = "$dir\iometer.zip"
            (New-Object System.Net.WebClient).DownloadFile($FileURI,$output)

            $disks = Get-PhysicalDisk –CanPool $true
			New-StoragePool -FriendlyName "DataPool" -StorageSubsystemFriendlyName "Storage Spaces*" -PhysicalDisks $disks | New-VirtualDisk -FriendlyName "DataDisk" -UseMaximumSize -NumberOfColumns $disks.Count -ResiliencySettingName "Simple" -ProvisioningType Fixed -Interleave 65536 | Initialize-Disk -Confirm:$False -PassThru | New-Partition -DriveLetter H –UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "DATA" -Confirm:$false			
		    
        } 

		TestScript = { 
			Test-Path H:\ 
		} 
		GetScript = { <# This must return a hash table #> }          }   
  }
} 