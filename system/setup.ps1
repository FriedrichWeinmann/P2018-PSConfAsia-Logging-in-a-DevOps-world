$setupCode = {
    $rootPresentationPath = Get-PSFConfigValue -FullName PSDemo.Path.PresentationsRoot -Fallback "F:\Code\Github"
    $tempPath = Get-PSFConfigValue -FullName psutil.path.temp -Fallback $env:TEMP

    $null = New-Item -Path $tempPath -Name demo -Force -ErrorAction Ignore -ItemType Directory
    $null = New-PSDrive -Name demo -PSProvider FileSystem -Root $tempPath\demo -ErrorAction Ignore
    Set-Location demo:
    Get-ChildItem -Path demo:\ -ErrorAction Ignore | Remove-Item -Force -Recurse

    $filesRoot = Join-Path $rootPresentationPath "P2018-PSConfAsia-Logging-in-a-DevOps-world\powershell"
    
    Add-Type -Path (Join-Path (Get-Module dbatools -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).ModuleBase "bin\dbatools.dll")
    function prompt {
        $string = ""
        try
        {
            $history = Get-History -ErrorAction Ignore
            if ($history)
            {
                $insert = ([Sqlcollaborative.Dbatools.Utility.DbaTimeSpanPretty]($history[-1].EndExecutionTime - $history[-1].StartExecutionTime)).ToString().Replace(" s", " s ")
                $padding = ""
                if ($insert.Length -lt 9) { $padding = " " * (9 - $insert.Length) }
                $string = "$padding[<c='red'>$insert</c>] "
            }
        }
        catch { }
        Write-PSFHostColor -String "$($string)Demo:" -NoNewLine
        
        "> "
    }
    Import-Module PSUtil

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

    function Test-DebugLevel {
        [CmdletBinding()]
        param ()
        Write-PSFMessage -Level Verbose -Message "Message (Verbose)"
    
        Write-PSFMessage -Level Debug -Message "Message (Debug)"
        Write-PSFMessage -Level Debug -Message "Message (Debug Breakpoint)" -Breakpoint
    }
}
. $setupCode
Set-Content -Value $setupCode -Path $profile.CurrentUserCurrentHost