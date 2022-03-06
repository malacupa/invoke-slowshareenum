# Invoke-SlowShareEnum

Wrapper around `net view` to use in internal penetration test or for any other review of available files on SMB shares in Windows domain. Enumerates files and folders in shares on all AD domain-joined computers and outputs 1 CSV file for each found share. The generated CSV files can then be reviewed to find sensitive files. It enumerates in parallel but isn't very fast.

## Install

```powershell
. .\Invoke-SlowShareEnum.ps1
```

## Usage

```powershell
Get-Help Invoke-SlowShareEnum -Detailed

NAME
    Invoke-SlowShareEnum

SYNOPSIS
    Enumerate files and folders in shares on all AD domain-joined computers, outputs in CSV format, 1 file for each share.


SYNTAX
    Invoke-SlowShareEnum [[-ComputerFile] <FileInfo>] [[-SharesFile] <FileInfo>] [[-StartFrom] <String>] [[-JobCount] <Int32>] [<CommonParameters>]


DESCRIPTION
    Creates folder `sseout` on current users desktop which will contain:

     - Log inside `sseout\0_share_enum_log.txt` on user's desktop (appends to file)
     - Found AD computers into `sseout\0_domain_computers.txt` (overwrites the file)
     - Found AD shares into `sseout\0_domain_shares.txt` (overwrites the file)
     - All files and folders accessible by current user in separate files for each share UNC path, e.g. \\server1\share3 will create `sseout\server1_share3.txt` (overwrites the files)


PARAMETERS
    -ComputerFile <FileInfo>
        Optional path to file containing one host per line to scan for available shares

    -SharesFile <FileInfo>
        Optional path to file containing one UNC share path per line to scan for available files

    -StartFrom <String>
        Optional UNC share path that allows to start enumeration from specific share in the shares list

    -JobCount <Int32>
        Optional number of jobs to run share enun/file listing with, default is 2

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https:/go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS C:\>Invoke-SlowShareEnum
```

Example output for one of generated CSV files:
```
Get-Content C:\Users\testuser\Desktop\sseout\DC01_Users.txt

"FullName","Length","LastWriteTime","Attributes"
"\\DC01\Users\Administrator",,"6/10/2019 12:24:49 PM","Directory"
"\\DC01\Users\Administrator\Documents",,"7/8/2020 4:51:01 AM","ReadOnly, Directory"
"\\DC01\Users\Administrator\Documents\adminfolder",,"7/8/2020 4:51:05 AM","Directory"
"\\DC01\Users\Administrator\Documents\adminfolder\New Text Document.txt","0","7/8/2020 4:51:05 AM","Archive"
```

## Similar Tools
This script is nothing new, there are others like it, e.g:

 - [Snaffler](https://github.com/SnaffCon/Snaffler) in C#
 - [ShareAudit.ps1](https://gist.github.com/HarmJ0y/72be6fba0b55409e0923) in PowerShell
 - `Invoke-FileFinder` and others from [PowerView](https://github.com/PowerShellMafia/PowerSploit/tree/master/Recon) in PowerShell
 - [smbspider](https://github.com/T-S-A/smbspider) in Python
 - [smbmap](https://github.com/ShawnDEvans/smbmap) in Python
 - `Spider_plus` module from [CrackMapExec](https://github.com/byt3bl33d3r/CrackMapExec) in Python
 - [nullinux](https://github.com/m8r0wn/nullinux) in Python
 - [smb-enumerate-shares](https://github.com/SylverFox/smb-enumerate-shares) in Node.js
 - [SharpShares](https://github.com/djhohnstein/SharpShares) in C#, enumerates shares only
 - [SharpShares](https://github.com/mitchmoser/SharpShares) by mitchmoser in C#, enumerates shares only
 - [shareenum](https://github.com/CroweCybersecurity/shareenum) in C
 - [Plunder 2](http://joshstone.us/plunder2/) in Ruby
 - [SoftPerfect Network Scanner](https://www.softperfect.com/products/networkscanner/) commercial tool with GUI
 - [MAN-SPIDER](https://github.com/blacklanternsecurity/MANSPIDER) in Python, searches for files by extension and also content
 - [SMBSR](https://github.com/oldboy21/SMBSR) in Python, get list of computers from AD, detect shares, match by patterns
 - [SMBeagle](https://github.com/punk-security/SMBeagle) in C#, detects also weak ACLs, supports export to CSV or Elasticsearch
 - [FindUncommonShares](https://github.com/p0dalirius/FindUncommonShares) in Python, only finds shares, multithreaded
 - ??? 
 
## License
[MIT](https://choosealicense.com/licenses/mit/)
