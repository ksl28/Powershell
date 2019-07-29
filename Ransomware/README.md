# Ransomware Protection by FSRM

## Description:
Powershell script that contains a single module to install, configure and update FSRM, in order to block Ransomware.
The module is designed to either create the initial configuration, if none of the settings are present.
If the settings are present, it will update the definitions instead.

The module works with both Workgroup and Active Directory domain joined servers (read Features list for more info).

## How it works
The module creates 2 **hidden** folders, under each of the shares defined

_ransomprotection

ZZZ_ransomprotection

The folder names are named to make sure, that the folders are the first and last folders, within the share folder.

The module creates a list of killswitch files, under each of the hidden folders - each with different file extensions.  
These files are excluded from FSRM monitoring, and hopefully encrypted in case of an Ransomware attack.
When the HELP_DECRYPT (or similar) files are created within the same folder, then FSRM starts blocking.

For Workgroup deployments, the user is locked out of **all smbshares** instantly.
For Active Directory deployments, the user is locked out of **all smbshares** instantly, but also disabled within Active Directory.




## Requirements:
Powershell 5 or higher
Active Directory deployments only:
An user account with access, to disable user accounts in Active Directory
Access to all domain controllers on port TCP/5985 from the server, hosting the FSRM role.

## Installation:
Import-module <path to module> -force

## Features included:
**General**
  - Installs FSRM if not already installed
  - Creates folder at C:\fsrm

**Verify-SMBShare**
  - Verifies that the share(s) are present
  - Verifies that the file system path is present

**Set-FSRMGlobalSettings**
  - Defines global SMTP server
  - Defines global Admin recipient
  - Defines global source mail
  - Sends test mail to verify the mail flow
  - Defines notification limits (Eventlog and Command)

**Set-FSRMFileSystem**
  - Checks if the 2 folders are already present
    - If present: updates the folder with new killswitch files
    - If NOT present: creates the folders, and add the killswitch files

**Set-FileGroup**
  - Checks if the FSRM File Group is already present.
    - If present: Updates the File Group settings, to match the module.
    - If NOT present: Creates the File Group, with the settings from the module.
  - Excludes the killswitch files.
  - Includes everything else, inside the hidden folders.
  
**Set-FileScreenTemplate**
  - Creates an script at C:\fsrm\scripts\RevokeSMBAccess.ps1 (used for blocking the infected user).
    - The script will set Deny access on all SMB shares, if user / the ransomware creates files in the hidden folders
  - Checks if the File Screen template is present.
    - If present: Updates the FSRM notifications (Mail, Eventlog, Command).
    - If NOT present: Creates the FSRM notifications (Mail, Eventlog, Command).
  
**Set-FileScreen**
  - Checks if the File Screen is present, for each share defined
    - If present: Updates the File Screen, based on the File Screen Template
    - If NOT present: Creates the File Screen, based on the File Screen Template

**Verify-ADConnectivity**
  - ONLY USED FOR ACTIVE DIRECTORY DEPLOYMENTS!
  - Tests if port TCP/5985 is open on the $env:LOGONSERVER
  
**Set-EventTrigger**
  - ONLY USED FOR ACTIVE DIRECTORY DEPLOYMENTS!
  - Creates an script at C:\FSRM\scripts\DisableADUser.ps1 (used for disabling the infected user).
  - Check if the "Trigger Ransomware protection" task schedule is present.
    - If present: Skipping
    - If NOT present: Defines an scheduled task, that triggers on Event ID 8215 with the "SRMSVC" source
    
    

## Examples:
**Workgroup**
Install-RansomwareProctection -Type WorkGroup -Shares Share1,Share2 -SMTPServer mail.domain.com -AdminMail support@domain.com -FromMail fsrm@domain.com
  
**ActiveDirectory**
Install-RansomwareProctection -Type ActiveDirectory -Shares Share1,Share2 -SMTPServer mail.domain.com -AdminMail support@domain.com -FromMail fsrm@domain.com

To include all non system shares (Admin$, IPC$, etc) set -Shares to "allshares"
Install-RansomwareProctection -Type ActiveDirectory -Shares allshares -SMTPServer mail.domain.com -AdminMail support@domain.com -FromMail fsrm@domain.com
