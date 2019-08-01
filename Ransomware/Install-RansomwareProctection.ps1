# Description: Module for installing and configuring FSRM, to protect against ransomware
#
# Author: Kristian Leth 
#
# Version: 1.1
#
# Source: https://github.com/ksl28/powershell
#
Function Install-RansomwareProctection {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('WorkGroup','ActiveDirectory')]
        [string]$Type,
        [Parameter(Mandatory=$true)]
        [array]$Shares,
        [Parameter(Mandatory=$false)]
        [string]$SMTPServer,
        [Parameter(Mandatory=$false)]
        [String]$AdminMail,
        [Parameter(Mandatory=$false)]
        [String]$FromMail
    )
    
    #Running prereqs 
    if ($PSVersionTable.PSVersion.Major -lt "5") {
        Write-Host "Powershell version 5 or higher is required! - exiting" -ForegroundColor Red
        break
    }
    if ($(Get-WindowsFeature -Name FS-Resource-Manager).InstallState -ne "Installed") {
        Write-Host "FSRM is not installed... Installing it" -ForegroundColor Yellow
        try {
            Install-WindowsFeature -Name FS-Resource-Manager –IncludeManagementTools -Confirm:$false -ErrorAction Stop
        }
        catch {
            Write-Host "Failed to install FSRM - aborting!" -ForegroundColor Red
            $_.Exception.Message
            break
        }
        
        Try {
            Import-Module -Name FileServerResourceManager -Force -ErrorAction Stop
        }
        catch {
            Write-Host "Failed to import FSRM module... exiting" -ForegroundColor Red
            $_.Exception.Message
            break
        }

        #After FSRM installation the service is required to be restarted...
        try {
            Restart-Service -Name srmsvc -Force -ErrorAction stop
        }
        catch {
            Write-Host "Failed to configure the FSRM service... exiting" -ForegroundColor Red
            $_.Exception.Message
            break
        }

        if (!(Test-Path -Path c:\fsrm\scripts)) {
            New-Item -ItemType Directory -Path C:\fsrm\scripts
        }
        
    }
    #Finds all shares, if "allshares" was used for -Shares parameter
    if ($Shares -eq "allshares") {
        #Null the array to remove "allshares" from the list
        $Shares = @()
        $SMBShares = Get-SmbShare -Special:$false | Select-Object Name 
        foreach ($SMBShare in $SMBShares) {
            $Shares += @($SMBShare.name)
        }
    }
    
        
    #Global
    
    $KillSwitchFileNames = @("killswitch.txt","killswitch.doc","killswitch.docx","killswitch.pdf","killswitch.jpg","killswitch.png")
    $KillSwitchFolderNames = @("_ransomprotection","ZZZ_ransomprotection")
    $FSRMFileScreenTemplateName = "FST_Block_Ransomware"
    $FSRMFileGroupName = "FG_Block_Ransomware"

     
    Function Approve-SmbShare {
        Foreach ($Share in $Shares) {
            try {
                Get-SmbShare -Name $Share -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Host "Verify SMB Share: Failed at finding share $($Share) - check for typo" -ForegroundColor Red
                #Sleeping to make sure, that user will see the error
                break
            }
        }
    }
    
    function Set-FSRMGlobalSettings {
        if ($SMTPServer) {
            try {
                Set-FsrmSetting -SmtpServer $SMTPServer
                Start-Sleep 3
                Restart-Service -Name srmsvc -Force -ErrorAction stop
                Start-Sleep 3
                Write-Host "Global Settings: Setting the SMTP server to $SMTPServer..." -ForegroundColor Green    
            }
            catch {
                Write-Host "Global Settings: Failed at defining the SMTPServer... Exiting" -ForegroundColor Red
                $_.Exception.Message
                break
            }
         
            if ($FromMail) {
                try {
                    Set-FsrmSetting -FromEmailAddress $FromMail
                    Write-Host "Global Settings: Defining the global admin mail to $FromMail..." -ForegroundColor Green
                }
                catch{
                    Write-Host "Global Settings: Failed at defining the global admin... Exiting" -ForegroundColor Red
                    $_.Exception.Message
                    break
                }
            }
            if ($AdminMail) {
                try {
                    Set-FsrmSetting -AdminEmailAddress $AdminMail -ErrorAction Stop
                    Write-Host "Global Settings: Setting the global admin mail to $AdminMail..." -ForegroundColor Green
                    Send-FsrmTestEmail -ToEmailAddress $AdminMail -Confirm:$false -ErrorAction Stop
                    Write-Host "Global Settings: Sending an testmail to $AdminMail - Please verify...!" -ForegroundColor Green
                }
                catch{
                    Write-Host "Global Settings: Failed at defining the global admin or send mail... Exiting" -ForegroundColor Red
                    $_.Exception.Message
                    break
                }
            }
        }
        
        
        try {
            Set-FsrmSetting -EventNotificationLimit "1" -ErrorAction Stop
            Set-FsrmSetting -CommandNotificationLimit "1" -ErrorAction Stop
            Write-Host "Global Settings: Defining the global notfication limits..." -ForegroundColor Green
        }
        catch {
            Write-Host "Global Settings: Failed at defining the global notification limits... Exiting" -ForegroundColor Red
            $_.Exception.Message
            break
        }
        Write-Host ""
    }

    function Set-FSRMFileSystem {
        foreach ($Share in $Shares) {
           
            try {
                $Path = Get-SmbShare -Name $Share
                if ($(Test-Path -Path $Path.path) -eq "True") {
                    foreach ($KillSwtichFolderName in $KillSwitchFolderNames) {
                    #Ensure that the folder isnt already present
                        if ($(Test-Path -Path $($Path.path + "\" + $KillSwtichFolderName)) -ne "True") {
                            Write-Host "File System: Found the path $($path.Path) - creating folder $KillSwtichFolderName" -ForegroundColor Green
                            New-Item -ItemType Directory -Path $($path.Path) -Name $KillSwtichFolderName -Force | Out-Null
                            (Get-item -Path $($Path.Path + "\" + $KillSwtichFolderName)).Attributes = 'Hidden'
                            foreach ($KillSwitchFileName in $KillSwitchFileNames) {
                                $File = New-Object System.IO.FileStream $($Path.Path + "\" + $KillSwtichFolderName +"\" + $KillSwitchFileName), Create, ReadWrite
                                $File.SetLength(2MB)
                                $File.Close() | Out-Null
                                Write-Host "File System - file: Created the $KillSwitchFileName" -ForegroundColor Green
                            }
                        }
                        else {
                            Write-Host "File System: $($Path.path + "\" + $KillSwtichFolderName) already exists - skipping" -ForegroundColor Yellow
                            #Ensure that all files are present
                            if ($(Get-ChildItem -Path $($Path.Path + "\" + $KillSwtichFolderName) -Recurse).count -ne $KillSwitchFileNames.Count) {
                                foreach ($KillSwitchFileName in $KillSwitchFileNames) {
                                    $File = New-Object System.IO.FileStream $($Path.Path + "\" + $KillSwtichFolderName +"\" + $KillSwitchFileName), Create, ReadWrite
                                    $File.SetLength(2MB)
                                    $File.Close() | Out-Null
                                }    
                                Write-Host "File System - file: Missing killswitch files in $($Path.Path + "\" + $KillSwtichFolderName)... Creating them" -ForegroundColor yellow
                            }
                        }
                    }
                } 
            }
            catch {
                Write-Host "Failed at storing $KillSwitchFileName at $($Path.Path + "\" + $KillSwtichFolderName)" -ForegroundColor Red
                $_.Exception.Message
                break
            }
        }
    Write-Host ""
    }

    function Set-FileGroup {
        Write-Host ":File Group Settings:" -ForegroundColor Green
        
        Try {
            #Making sure that the group is not present - otherwise its being updated
            if (Get-FsrmFileGroup -Name $FSRMFileGroupName -ErrorAction SilentlyContinue) {
                Set-FsrmFileGroup -Name $FSRMFileGroupName -IncludePattern *.* -ExcludePattern $Global:KillSwitchFileNames
                Write-Host "File Group: $($FSRMFileGroupName) already exists... updating the patterns" -ForegroundColor yellow
            }
            else {
                try {
                    New-FsrmFileGroup -Name $FSRMFileGroupName -IncludePattern *.* -ExcludePattern $Global:KillSwitchFileNames -Description "Ransomware protection" -ErrorAction Stop | Out-Null
                }
                catch {
                    Write-Host "File Group: Failed at creating the FSRM File Group" -ForegroundColor Red
                    $_.Exception.Message  
                    break
                }
                Write-Host "File Group: File Group $FSRMFileGroupName is NOT present... Creating and excluding $($Global:KillSwitchFileNames.Count) files" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "File Group: Failed at creating or updating the FSRM File Group" -ForegroundColor Red
            $_.Exception.Message  
            break
        }
    Write-Host ""
    }

    function Set-FileScreenTemplate {
        Write-Host ":::File Screen Template Settings:::" -ForegroundColor Green
        $CommandFile = "C:\FSRM\scripts\RevokeSMBAccess.ps1"
        try {
            New-Item -Path $CommandFile -ItemType File -Value 'param( [string]$username = "" ) Get-SmbShare -Special $false | ForEach-Object { Block-SmbShareAccess -Name $_.Name -AccountName "$username" -Force }' -Force -ErrorAction Stop | Out-Null
            Write-Host "File Screen Template: Creating the Command file at $CommandFile..." -ForegroundColor Green
        }
        catch {
            Write-Host "File Screen Template: Failed Creating the Command file at $CommandFile..." -ForegroundColor Red
            $_.Exception.Message
            break
        }
        
        try {
            #Making sure that the group is not present - otherwise its being updated
            $FSRMNotifyMail = New-FsrmAction -Type Email -MailTo $AdminMail -Subject "Potential Ransomware Infection!" -Body "User [Source Io Owner] attempted to save [Source File Path] to [File Screen Path] on the [Server] server. This file is in the [Violated File Group] file group, which is not permitted on the server."
            $FSRMNotifyCommand = New-FsrmAction -Type Command -Command "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -CommandParameters "-Command `"& {C:\FSRM\scripts\RevokeSMBAccess.ps1 -username '[Source Io Owner]'}`"" -SecurityLevel LocalSystem -KillTimeOut 0
            $FSRMNotifyEvent = New-FsrmAction -Type Event -EventType Warning -Body "User [Source Io Owner] attempted to save [Source File Path] to [File Screen Path] on the [Server] server. This file is in the [Violated File Group] file group, which is not permitted on the server."
            $FSRMNotify = @($FSRMNotifyMail,$FSRMNotifyCommand,$FSRMNotifyEvent)
            if (Get-FsrmFileScreenTemplate -Name $FSRMFileScreenTemplateName -ErrorAction SilentlyContinue) {
                Set-FsrmFileScreenTemplate -Name $FSRMFileScreenTemplateName -IncludeGroup $FSRMFileGroupName -Active:$false -Notification $FSRMNotify -ErrorAction Stop | Out-Null
                Write-Host "File Screen Template: File Screen Template $FSRMFileScreenTemplateName exists... Updating" -ForegroundColor yellow
            }
            else {
                New-FsrmFileScreenTemplate -Name $FSRMFileScreenTemplateName -IncludeGroup $FSRMFileGroupName -Active:$false -Notification $FSRMNotify -ErrorAction Stop | Out-Null
                Write-Host "File Screen Template: File Screen Template $FSRMFileScreenTemplateName is NOT present... Creating" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "File Screen Template: Failed at creating or updating the FileScreenTemplate!" -ForegroundColor Red
            $_.Exception.Message  
            break 
        }
    Write-Host ""
    }

    function Set-FileScreen {
        Write-Host ":::File Screen Settings:::" -ForegroundColor Green
        foreach ($Share in $Shares) {
            foreach ($KillSwtichFolderName in $KillSwitchFolderNames) {
                $SharePath = $(Get-SmbShare -Name $Share).Path + "\" + $KillSwtichFolderName
                try {
                    if (Get-FsrmFileScreen -Path $SharePath -ErrorAction SilentlyContinue) {
                        Set-FsrmFileScreen -Path $SharePath -IncludeGroup $FSRMFileGroupName
                        Write-Host "File Screen: File Screen $SharePath exists... Updating" -ForegroundColor yellow
                    }
                    else {
                        New-FsrmFileScreen -Path $SharePath -Template $FSRMFileScreenTemplateName | Out-Null
                        Write-Host "File Screen: File Screen $SharePath is NOT present... Creating" -ForegroundColor Green
                    }
                }
                catch {
                    Write-Host "File Screen: Failed at creating or updating the File Screen!" -ForegroundColor Red
                    $_.Exception.Message  
                    break
                }
            }
        }
    Write-Host ""
    }

    function Approve-ADConnectivity {
        $DomainController = $env:LOGONSERVER.Trim("\")
        
        $YesOrNo = Read-Host "AD Connectivity: Is port TCP/5985 is open on $DomainController - Ensure that it is! (y/n)"
            while("y","n" -notcontains $YesOrNo ){
                $YesOrNo = Read-Host "AD Connectivity: Please enter your response (y/n)"
            }
        if ($YesOrNo -eq "y") {
            if ($(Test-NetConnection -ComputerName $DomainController -Port 5985).TcpTestSucceeded -eq "True") {
                Write-Host "AD Connectivity: Port 5985 is open..." -ForegroundColor Green
                Write-Host ""
                Write-Host ""
                Write-Host ""
                Write-Host ""
            }
            else {
                Write-Host "AD Connectivity: Port 5985 is NOT open - exiting..." -ForegroundColor Red
                break
            }
        }
        else {
            Write-Host "AD Connectivity: Port 5985 is NOT open - exiting..." -ForegroundColor Red
            break
        }

        Write-Host ""        
    }




    Function Set-EventTrigger {
        $ADCommandFile = "C:\FSRM\scripts\DisableADUser.ps1"
        $ADCommandFileValue = @'
$InfectedUsers = Get-WinEvent -LogName Application | Where-Object {$_.ProviderName -eq "SRMSVC" -and $_.Id -eq "8215"} | select -First 1
$SamAccountName = $InfectedUsers.Message.Split("\")[1].split(" ")[0]
$DomainController = $env:LOGONSERVER.Trim("\")
Invoke-Command -ComputerName $DomainController -ScriptBlock {Disable-ADAccount -Identity $args[0]} -ArgumentList $SamAccountName
'@
        try {
            New-Item -Path $ADCommandFile -ItemType File -Value $ADCommandFileValue -Force -ErrorAction Stop | Out-Null
            Write-Host "AD Event Trigger: Creating the Command file at $ADCommandFile..." -ForegroundColor Green
        }
        catch {
            Write-Host "AD Event Trigger: Failed Creating the Command file at $ADCommandFile..." -ForegroundColor Red
            $_.Exception.Message
            break
        }
        $SchedTaskName = "Trigger Ransomware protection"
        
        if ((Get-ScheduledTask -TaskName $SchedTaskName -ErrorAction SilentlyContinue)) {
            Write-Host "Task Scheduler: $SchedTaskName already exists... skipping this part" -ForegroundColor Yellow
        }
        else {
            try {
                $SchedTaskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -NoLogo -NonInteractive -NoProfile -WindowStyle Hidden -file $ADCommandFile" -ErrorAction stop
                $SchedTrigger = Get-CimClass MSFT_TaskEventTrigger root/Microsoft/Windows/TaskScheduler | New-CimInstance -ClientOnly -ErrorAction stop
                $SchedTrigger.Enabled = $true 
                $SchedTrigger.Subscription = '<QueryList><Query Id="0" Path="Application"><Select Path="Application">*[System[Provider[@Name=''SRMSVC''] and EventID=8215]]</Select></Query></QueryList>' 
                $Settings = New-ScheduledTaskSettingsSet -ErrorAction stop
                $RegSchTaskParameters = @{ 
                TaskName    = $SchedTaskName
                Description = 'Trigger on Ransomware Attacks'
                TaskPath    = '\Event Viewer Tasks\'
                Action      = $SchedTaskAction
                Settings    = $Settings
                Trigger     = $SchedTrigger
                }
                $Username = Read-Host "Task Scheduler: Enter DOMAIN ADMIN username (ex: domain\admin1):"
                $SecurePassword = $password = Read-Host "Enter password:" -AsSecureString
                $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword 
                $Password = $Credentials.GetNetworkCredential().Password 
                Register-ScheduledTask  @RegSchTaskParameters -User $Username -Password $password -RunLevel Highest -ErrorAction stop   
            }
            catch {
                Write-Host "Task Scheduler: Failed at creating the Scheduled task" -ForegroundColor Red
                $_.Exception.Message  
                break
            }
        }
    }

    switch ($Type) {
        WorkGroup {
            Clear-Host
            Write-Host "############################" -ForegroundColor White
            Write-Host "### WORKGROUP DEPLOYMENT ###" -ForegroundColor White
            Write-Host "############################" -ForegroundColor White
            Approve-SmbShare
            Set-FSRMGlobalSettings
            Set-FSRMFileSystem
            Set-FileGroup
            Set-FileScreenTemplate
            Set-FileScreen
        }

        ActiveDirectory {
            Clear-Host
            Write-Host "##################################" -ForegroundColor White 
            Write-Host "### ACTIVEDIRECTORY DEPLOYMENT ###" -ForegroundColor White
            Write-Host "##################################" -ForegroundColor White
            Approve-SmbShare
            Approve-ADConnectivity
            Set-FSRMGlobalSettings
            Set-FSRMFileSystem
            Set-FileGroup
            Set-FileScreenTemplate
            Set-FileScreen
            Set-EventTrigger
        }
    }
}
