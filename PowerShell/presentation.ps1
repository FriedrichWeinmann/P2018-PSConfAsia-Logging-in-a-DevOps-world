# Failsafe
break

 #----------------------------------------------------------------------------# 
 #                             Logging in Action                              # 
 #----------------------------------------------------------------------------# 

# Write a message
Write-PSFMessage "Test"
Write-PSFMessage "Test 2" -Verbose
# Retrieve it
Get-PSFMessage
# Same as before, but ... Level?:
Write-PSFMessage -Level Verbose -Message "Test" -Verbose
# What Levels?
Write-PSFMessage -Level Host -Message "Test to Host"
Write-PSFMessage -Level Warning -Message "Test warning"
Write-PSFMessage -Level Debug -Message "Test Debug" -Debug

# Fooling around
Write-PSFMessage -Level Host -Message 'This <c="em">might</c> get a <c="sub">little</c> <c="red">colorful</c>!'

# Debug v2
function Test-DebugLevel {
    [CmdletBinding()]
    param ()
    Write-PSFMessage -Level Verbose -Message "Message (Verbose)"

    Write-PSFMessage -Level Debug -Message "Message (Debug)"
    Write-PSFMessage -Level Debug -Message "Message (Debug Breakpoint)" -Breakpoint
}
Test-DebugLevel
Test-DebugLevel -Verbose
Test-DebugLevel -Debug

# Log...file?
Get-PSFConfigValue -FullName psframework.logging.filesystem.logpath | Invoke-Item

# Failing with a plan
try { $null.GetFoo() }
catch { Write-PSFMessage -Level Warning -Message 'I failed' -ErrorRecord $_ }

# Tracking Stuff
function Show-Message
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        $InputObject,

        [string]
        $Name
    )

    begin {
        Write-PSFMessage -Message "[$Name] Beginning"
    }
    process {
        foreach ($item in $InputObject) {
            Write-PSFMessage -Message "[$Name] Processing $item" -Target $item -Tag start
            $item
            Write-PSFMessage -Message "[$Name] Finished processing $item" -Target $item -Tag end
        }
    }
    end {
        Write-PSFMessage -Message "[$Name] Ending"
    }
}
1..3 | Show-Message -Name "First" | Show-Message -Name "Second" | Show-Message -Name "Third"


 #----------------------------------------------------------------------------# 
 #                                Going DevOps                                # 
 #----------------------------------------------------------------------------# 

# The full data revealed
Get-PSFMessage | Select-Object -Last 1 | fl *

$null = 1..5 | Start-RSJob {
    1..10 | ForEach-Object {
        Start-Sleep -Milliseconds (Get-Random -Minimum 1000 -Maximum 5000)
        Write-PSFMessage -Message "Asynchronous $_"
    }
} -Throttle 99
Get-PSFMessage | Where-Object Message -Like "Asynchronous*" | Format-Table Timestamp, Runspace, Message


 #----------------------------------------------------------------------------# 
 #                             Extending Logging                              # 
 #----------------------------------------------------------------------------# 

# a) The logfile provider
#--------------------------

# Listing the available plugins
Get-PSFLoggingProvider

# A dedicated logfile
$paramSetPSFLoggingProvider = @{
	Name	 = 'logfile'
	filepath = (Resolve-PSFPath -Path 'demo:\log %day% %dayofweek%.json' -NewChild -Provider FileSystem)
	filetype = 'json'
	Enabled  = $true
}
Set-PSFLoggingProvider @paramSetPSFLoggingProvider
Write-PSFMessage -Message 'Test Message 1'
Write-PSFMessage -Message 'Test Message 2'
code (Resolve-PSFPath 'demo:\log 20 Saturday.json')
Set-PSFLoggingProvider -Name logfile -Enabled $false


# b) Creating a simple provider
#-------------------------------

Register-PSFLoggingProvider -Name EventLog1 -MessageEvent {
    param ($Message)
    
    $paramWriteEventLog = @{
        LogName   = "Windows PowerShell"
        Source    = "PowerShell"
        EntryType = 'Information'
        Category  = 1
        EventId   = 1000
        Message   = ($Message | Format-List * | Out-String)
    }
    
    Write-EventLog @paramWriteEventLog
} -Enabled


# c) Handling errors
#---------------------

Register-PSFLoggingProvider -Name EventLog2 -MessageEvent {
    param ($Message)
    
    $paramWriteEventLog = @{
        LogName   = "Windows PowerShell"
        Source    = "PowerShell"
        EntryType = 'Information'
        Category  = 1
        EventId   = 1000
        Message   = ($Message | Format-List * | Out-String)
    }
    
    Write-EventLog @paramWriteEventLog
} -ErrorEvent {
    param ($Exception)
    
    $paramWriteEventLog = @{
        LogName   = "Windows PowerShell"
        Source    = "PowerShell"
        EntryType = 'Error'
        Category  = 1
        EventId   = 666
        Message   = ($Exception | ConvertTo-PSFClixml)
    }
    
    Write-EventLog @paramWriteEventLog
} -Enabled
try { $null.GetFoo() }
catch { Write-PSFMessage -Level Warning -Message "Failed" -ErrorRecord $_ }

# Get Error Message from Event
Get-WinEvent -FilterHashtable @{
    LogName = 'Windows PowerShell'
    Id = 666
} | Select-Object -ExpandProperty Properties | Select-Object -ExpandProperty Value | ConvertFrom-PSFClixml


# d) Warnings should be warnings
#---------------------------------

Register-PSFLoggingProvider -Name EventLog3 -MessageEvent {
    param ($Message)
    
    if ($Message.Level -like 'Warning') {
        $eventLogType = 'Warning'
        $eventLogID = 1001
    }
    else {
        $eventLogType = 'Information'
        $eventLogID = 1000
    }

    $paramWriteEventLog = @{
        LogName   = "Windows PowerShell"
        Source    = "PowerShell"
        EntryType = $eventLogType
        Category  = 1
        EventId   = $eventLogID
        Message   = ($Message | Format-List * | Out-String)
    }
    
    Write-EventLog @paramWriteEventLog
} -ErrorEvent {
    param ($Exception)
    
    $paramWriteEventLog = @{
        LogName   = "Windows PowerShell"
        Source    = "PowerShell"
        EntryType = 'Error'
        Category  = 1
        EventId   = 666
        Message   = ($Exception | ConvertTo-PSFClixml)
    }
    
    Write-EventLog @paramWriteEventLog
} -Enabled
Write-PSFMessage -Level Warning -Message "Demo Warning"

# e) The full layout
#---------------------

code $filesRoot\pssqlite.provider.ps1