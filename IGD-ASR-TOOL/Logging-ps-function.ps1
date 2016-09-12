
# $HashInfo = "EventHashInformation"
function LogToEventLog($HashInfo,$EventMessage)
{

    if ($HashInfo -eq "EventHashInformation")
    {
            $EventHashInfo = @{
            LogName   = "LiftAndShiftLog"
            Source    = "scripts"
            EventId   = 30101
            EntryType = "Information"
        }
    }

    if ($HashInfo -eq "EventHashWarning")
    {
        $EventHashInfo = @{
        LogName   = "LiftAndShiftLog"
        Source    = "scripts"
        EventId   = 40101
        EntryType = "Warning" 
        }
    }
    if ($HashInfo -eq "EventHashError")
    {
        $EventHashInfo = @{
        LogName   = "LiftAndShiftLog"
        Source    = "scripts"
        EventId   = 50101
        EntryType = "Error"  
        }
    }

    $getEventLog = Get-EventLog -LogName "LiftAndShiftLog" -ErrorAction SilentlyContinue
    if ($getEventLog)
    {
        #Write-Host "Event Log LiftAndShiftLog is present"
        # Write-EventLog -LogName LiftAndShiftLog -Source scripts -Message $EventMessage -EventId 50101 -EntryType $EntryType
         Write-EventLog -Source $EventHashInfo.Source -LogName $EventHashInfo.LogName -EntryType $EventHashInfo.EntryType -EventId $EventHashInfo.EventId -Message $EventMessage
    }
    else
    {
         Write-Host "Event Log LiftAndShiftLog is not present"
         New-EventLog -LogName "LiftAndShiftLog" -Source Scripts
         Limit-EventLog -LogName  "LiftAndShiftLog" -OverflowAction OverwriteOlder -RetentionDays 1 -Maximum 20MB
         Write-EventLog -LogName LiftAndShiftLog -Source scripts -Message “EventLog for Lift And Shift created” -EventId 50001 -EntryType information
         #Write-EventLog -LogName LiftAndShiftLog -Source scripts -Message $EventMessage -EventId 50101 -EntryType $EntryType
         Write-EventLog -Source $EventHashInfo.Source -LogName $EventHashInfo.LogName -EntryType $EventHashInfo.EntryType -EventId $EventHashInfo.EventId -Message $EventMessage
    }

}

# -HashInfo can have only three type of values EventHashWarning, EventHashWarning, EventHashError
LogToEventLog -HashInfo "EventHashWarning" -EventMessage $Error[0]












