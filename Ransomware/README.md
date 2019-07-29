# Ransomware Protection by FSRM

## Description:
Powershell script that contains a single module, to install, configure and update FSRM, in order to block Ransomware.
The module is designed to either create the initial configuration, if none of the settings are present
If the settings are present, it will update the definitions instead.

The module works with both Workgroup and Active Directory domain joined servers (read Features list for more info).

## Requirements:
Powershell 5 or higher

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
**
