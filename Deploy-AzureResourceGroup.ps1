#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

Param(
    [string] [Parameter(Mandatory=$true)] $ResourceGroupLocation,
    [string] $ResourceGroupName = 'HCF-Lite',
    [switch] $UploadArtifacts,
    [string] $StorageAccountName,
    [string] $StorageContainerName = $ResourceGroupName.ToLowerInvariant() + '-stageartifacts',
    [string] $TemplateFile = '..\Templates\azuredeploy.json',
    [string] $TemplateParametersFile = '..\Templates\azuredeploy.parameters.json',
    [string] $ArtifactStagingDirectory = '..\bin\Debug\staging',
    [string] $DSCSourceFolder = '..\DSC'
)

Import-Module Azure -ErrorAction SilentlyContinue

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(" ","_"), "2.9")
} catch { }

Set-StrictMode -Version 3

$OptionalParameters = New-Object -TypeName Hashtable
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))

if ($UploadArtifacts) {
    # Convert relative paths to absolute paths if needed
    $ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactStagingDirectory))
    $DSCSourceFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $DSCSourceFolder))

    Set-Variable ArtifactsLocationName '_artifactsLocation' -Option ReadOnly -Force
    Set-Variable ArtifactsLocationSasTokenName '_artifactsLocationSasToken' -Option ReadOnly -Force

    $OptionalParameters.Add($ArtifactsLocationName, $null)
    $OptionalParameters.Add($ArtifactsLocationSasTokenName, $null)

    # Parse the parameter file and update the values of artifacts location and artifacts location SAS token if they are present
    $JsonContent = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json
    $JsonParameters = $JsonContent | Get-Member -Type NoteProperty | Where-Object {$_.Name -eq "parameters"}

    if ($JsonParameters -eq $null) {
        $JsonParameters = $JsonContent
    }
    else {
        $JsonParameters = $JsonContent.parameters
    }

    $JsonParameters | Get-Member -Type NoteProperty | ForEach-Object {
        $ParameterValue = $JsonParameters | Select-Object -ExpandProperty $_.Name

        if ($_.Name -eq $ArtifactsLocationName -or $_.Name -eq $ArtifactsLocationSasTokenName) {
            $OptionalParameters[$_.Name] = $ParameterValue.value
        }
    }

    # Create DSC configuration archive
    if (Test-Path $DSCSourceFolder) {
        Add-Type -Assembly System.IO.Compression.FileSystem
        $ArchiveFile = Join-Path $ArtifactStagingDirectory "dsc.zip"
        Remove-Item -Path $ArchiveFile -ErrorAction SilentlyContinue
        [System.IO.Compression.ZipFile]::CreateFromDirectory($DSCSourceFolder, $ArchiveFile)
    }

    $StorageAccountContext = (Get-AzureRmStorageAccount | Where-Object{$_.StorageAccountName -eq $StorageAccountName}).Context

    # Generate the value for artifacts location if it is not provided in the parameter file
    $ArtifactsLocation = $OptionalParameters[$ArtifactsLocationName]
    if ($ArtifactsLocation -eq $null) {
        $ArtifactsLocation = $StorageAccountContext.BlobEndPoint + $StorageContainerName
        $OptionalParameters[$ArtifactsLocationName] = $ArtifactsLocation
    }

    # Copy files from the local storage staging location to the storage account container
    New-AzureStorageContainer -Name $StorageContainerName -Context $StorageAccountContext -Permission Container -ErrorAction SilentlyContinue *>&1

    $ArtifactFilePaths = Get-ChildItem $ArtifactStagingDirectory -Recurse -File | ForEach-Object -Process {$_.FullName}
    foreach ($SourcePath in $ArtifactFilePaths) {
        $BlobName = $SourcePath.Substring($ArtifactStagingDirectory.length + 1)
        Set-AzureStorageBlobContent -File $SourcePath -Blob $BlobName -Container $StorageContainerName -Context $StorageAccountContext -Force
    }

    # Generate the value for artifacts location SAS token if it is not provided in the parameter file
    $ArtifactsLocationSasToken = $OptionalParameters[$ArtifactsLocationSasTokenName]
    if ($ArtifactsLocationSasToken -eq $null) {
        # Create a SAS token for the storage container - this gives temporary read-only access to the container
        $ArtifactsLocationSasToken = New-AzureStorageContainerSASToken -Container $StorageContainerName -Context $StorageAccountContext -Permission r -ExpiryTime (Get-Date).AddHours(4)
        $ArtifactsLocationSasToken = ConvertTo-SecureString $ArtifactsLocationSasToken -AsPlainText -Force
        $OptionalParameters[$ArtifactsLocationSasTokenName] = $ArtifactsLocationSasToken
    }
}

# Create or update the resource group using the specified template file and template parameters file
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force -ErrorAction Stop 

$output = New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                   -ResourceGroupName $ResourceGroupName `
                                   -TemplateFile $TemplateFile `
                                   -TemplateParameterFile $TemplateParametersFile `
                                   @OptionalParameters `
                                   -Force -Verbose

　
if ($output)
{
    Write-Output "enter the dragon!!"
    [int]$numberOfDiskToAttachFromPram =  $output.Parameters.numberOfDisks.Value
    [int]$numberOfInstances = $output.Parameters.numberOfInstances.Value
    [int]$dataDiskSize = $output.Parameters.dataDiskSize.Value
    [string]$dataDiskType = $output.Parameters.dataDiskType.Value
    [string]$prefixvalue = $output.Parameters.prefix.Value
    [string[]] $keyValues = $output.Outputs.Keys

    foreach ($item in $keyValues)
    {
        # extracting value for a object from the output, converting in string and convering the output in json format for easy read.
        $Objectvalue = Convertfrom-json $output.Outputs[$item].Value.ToString()
        $ServerName = $Objectvalue.osProfile.computerName
        $ServerName = $ServerName.TrimEnd('1')
        for ($i = 1; $i -le $numberOfInstances; $i++)
            { 
            $virtualMachineName = $ServerName + "$($i)"
            [int]$numberOfDiskToAttach = $numberOfDiskToAttachFromPram
            Write-Output "enteing the for loop for each server, servername $($virtualMachineName)"
            for ($DiskObject = 0; $DiskObject -lt $numberOfDiskToAttach; $DiskObject++)
                {
                [string]$diskName = $($virtualMachineName) + "-datadisk-" +$($DiskObject) 
                Write-Output "Building no. $($DiskObject) DiskConfig  and new azureRmDisk for computer $($virtualMachineName)"
                $diskConfig = New-AzureRmDiskConfig -AccountType $dataDiskType  -Location $ResourceGroupLocation -DiskSizeGB $dataDiskSize -CreateOption Empty
                $newDataDisk = New-AzureRmDisk -DiskName $diskName -Disk $diskConfig -ResourceGroupName $ResourceGroupName
                $getAzureVm = Get-AzureRmVM -Name $virtualMachineName -ResourceGroupName $ResourceGroupName
                # Joining the created managed disk to thier respective server.
                $vm = Add-AzureRmVMDataDisk -Name $newDataDisk.Name -VM $getAzureVm -Lun $DiskObject -CreateOption Attach -ManagedDiskId $newDataDisk.Id -Caching ReadWrite
                Update-AzureRmVM -VM $vm -ResourceGroupName $ResourceGroupName 
                 }
      }
    }
    
}
    else
{
    Write-Output -Verbose  "Error : Deployment had some issues, could not record the output result of template deployment"
}

    <#
    foreach ($item in $keyValues)
    {
        # extracting value for a object from the output, converting in string and convering the output in json format for easy read.
        $Objectvalue = Convertfrom-json $output.Outputs[$item].Value.ToString()
        $ServerName = $Objectvalue.osProfile.computerName
        
        [int]$numberOfDiskToAttach = $numberOfDiskToAttachFromPram
        for ($DiskObject = 0; $DiskObject -lt $numberOfDiskToAttach; $DiskObject++)
        { 
            # Creating Managed Disk
            [string]$diskName = $($ServerName) + "-datadisk-" +$($DiskObject)
            Write-Output "Building no. $($DiskObject) DiskConfig  and new azureRmDisk for computer $($ServerName)"
            $diskConfig = New-AzureRmDiskConfig -AccountType $dataDiskType  -Location $ResourceGroupLocation -DiskSizeGB $dataDiskSize -CreateOption Empty
            $newDataDisk = New-AzureRmDisk -DiskName $diskName -Disk $diskConfig -ResourceGroupName $ResourceGroupName
            $getAzureVm = Get-AzureRmVM -Name $ServerName -ResourceGroupName $ResourceGroupName
            # Joining the created managed disk to thier respective server.
            $vm = Add-AzureRmVMDataDisk -Name $newDataDisk.Name -VM $getAzureVm -Lun $DiskObject -CreateOption Attach -ManagedDiskId $newDataDisk.Id -Caching ReadWrite
            Update-AzureRmVM -VM $vm -ResourceGroupName $ResourceGroupName
        }
        
    }
}
else
{
    Write-Output -Verbose  "Error : Deployment had some issues, could not record the output result of template deployment"
}
#>
