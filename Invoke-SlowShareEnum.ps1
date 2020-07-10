function Invoke-SlowShareEnum {

<#
    .SYNOPSIS
        Enumerate files and folders in shares on all AD domain-joined computers, outputs in CSV format, 1 file for each share.

    .DESCRIPTION
        Creates folder `sseout` on current users desktop which will contain:

         - Log inside `sseout\0_share_enum_log.txt` on user's desktop (appends to file)
         - Found AD computers into `sseout\0_domain_computers.txt` (overwrites the file)
         - Found AD shares into `sseout\0_domain_shares.txt` (overwrites the file)
         - All files and folders accessible by current user in separate files for each share UNC path, e.g. \\server1\share3 will create `sseout\server1_share3.txt` (overwrites the files)


    .EXAMPLE

        Invoke-SlowShareEnum

    .PARAMETER ComputerFile
        Optional path to file containing one host per line to scan for available shares

    .PARAMETER SharesFile
        Optional path to file containing one UNC share path per line to scan for available files

    .PARAMETER StartFrom
        Optional UNC share path that allows to start enumeration from specific share in the shares list

    .PARAMETER JobCount
        Optional number of jobs to run share enun/file listing with, default is 2

#>
    Param
    (
        [System.IO.FileInfo]
        $ComputerFile,

        [System.IO.FileInfo]
        $SharesFile,

        [String]
        $StartFrom,

        [ValidateRange(1,100)]
        [int]
        $JobCount = 2
    )

    $jobs = [System.Collections.ArrayList]@()
    $timeoutseconds = 600
    $outd = "$env:USERPROFILE\desktop\sseout"
    $logf = "$outd\0_share_enum_log.txt"

    function log {
        param($str)
        Write-Output "$(Get-Date) $str" >> $logf
    }

    try {
        mkdir $outd *> $null
        $done = ([pscustomobject] @{cnt = 0}) # need to be object for pass-by-reference
        Write-Output "Saving to $outd"


        # enumerate computers
        if ($SharesFile -eq $null) {
            if ($ComputerFile -ne $null) {
                $comps = Get-Content $ComputerFile
                log "Loaded $($comps.Length) computers from $ComputerFile"
            } else {
                log "Enumerating AD computer objects from default DC"
                # get list of domain computers
                $searcher = New-Object System.DirectoryServices.DirectorySearcher
                $searcher.Filter = '(sAMAccountType=805306369)'
                $comps = $searcher.FindAll() | ForEach-Object { $_.properties.cn }
                $comps | Out-File -FilePath "$outd\0_domain_computers.txt" -Force
                log "Found $($comps.Length) possible computers in AD, saving into $outd\0_domain_computers.txt"
            }
        }

        # enumerate shares
        if ($SharesFile -ne $null) {
            $shares = [System.Collections.ArrayList] $(Get-Content $SharesFile)
            log "Loaded $($shares.Count) shares from $SharesFile"
        } else {
            log "Enumerating shares on $($comps.Length) computers"
            $shares = [System.Collections.ArrayList]@()
            $sb = {
                param($computer)

                # might handle timeout of net view better here
                net view $Computer 2>$null | findstr Disk | ForEach-Object { "\\$Computer\$($_.split(" ")[0])" }
            }

            function ReceiveFirstShareEnumJob {
                $done.cnt++
                $newShares = [System.Collections.ArrayList]@()
                if (Wait-Job -Id $jobs[0].Job -Timeout $timeoutseconds) {
                    $newShares = [System.Collections.ArrayList] $(Receive-Job -Id $jobs[0].Job)
                    if ($null -ne $newShares) { $shares.AddRange($newShares) }
                    log "Found $($newShares.Count) shares on $($jobs[0].Computer) ($($done.cnt)/$($comps.Length) done)"
                } else {
                    Stop-Job -Id $jobs[0].Job
                    log "Timeout enumerating shares on $($jobs[0].Computer) ($($done.cnt)/$($comps.Length) done)"
                }
                Remove-Job -Id $jobs[0].Job
                $jobs.RemoveAt(0)
            }

            $comps | ForEach-Object {
                $computer = $_
                $j = Start-Job -ScriptBlock $sb -ArgumentList @($computer)
                $jobs.Add(([pscustomobject] @{Job = $j.Id; Computer = $computer})) >$null
                if ($jobs.Count -eq $JobCount) {
                    ReceiveFirstShareEnumJob
                }
            }
            while ($jobs.Count -gt 0) { ReceiveFirstShareEnumJob }

            $shares | Out-File -FilePath "$outd\0_domain_shares.txt" -Force
            log "Found $($shares.Count) possible shares, storing into $outd\0_domain_shares.txt"
        }

        if ($StartFrom -ne "") {
            $StartFrom = If ($StartFrom[-1] -eq "\") { $StartFrom.Substring(0, $StartFrom.Length-1) } Else { $StartFrom }
            $shares = $shares | Select-Object -Skip $shares.IndexOf($StartFrom)
        }


        # enumerate files
        $done.cnt = 0
        $sb = {
            param($share, $outfn)

            Get-ChildItem -Recurse $share | Select-Object -Property Fullname,Length,Lastwritetime,Attributes | Export-Csv -Delimiter "," -Notypeinformation -Encoding UTF8 -Path $outfn
            # remove empty output files
            If ((Get-Content $outfn).Length -eq 0) {
            Remove-Item $outfn
            }
        }

        function ReceiveFirstFileEnumJob {
            $done.cnt++
            if (Wait-Job -Id $jobs[0].Job -Timeout $timeoutseconds) {
                log "Listing $($jobs[0].Share) done ($($done.cnt)/$($shares.Count))"
            } else {
                Stop-Job -Id $jobs[0].Job
                log "Timeout for $($jobs[0].Share) ($($done.cnt)/$($shares.Count)) done"
            }
            Remove-Job -id $jobs[0].Job
            $jobs.RemoveAt(0)
        }

        $shares | ForEach-Object {
            $share= $_
            # normalize output filename from "\\server1\share1" to "server1_share1.txt"
            $outfn = $share.Substring(2).Replace("\","_").Split([IO.Path]::GetInvalidFileNameChars()) -join ''
            $outfn = "$outd\$outfn.txt"

            log "Listing $share into $outfn"
            $j = Start-Job -scriptblock $sb -ArgumentList @($share, $outfn)
            $jobs.Add(([pscustomobject] @{Job = $j.Id; Share = $share})) >$null

            if ($jobs.Count -eq $JobCount) {
                ReceiveFirstFileEnumJob
            }
        }
        while ($jobs.Count -gt 0) { ReceiveFirstFileEnumJob }

        log "Done --- "
    } finally {
        if (($jobs -ne $null) -and ($jobs.Count -ne 0)) {
            log "Interrupt? Ending all jobs"
            $jobs | ForEach-Object { Stop-Job -Id $_.Job }
        }
    }
}
