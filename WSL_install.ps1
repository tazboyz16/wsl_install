##########################################################
# # Version: 0.39
# Creator(s): tazboyz16 
# Script to install WSL with approved linux distros
# Changelog:
#
# 2022-03-15 - 0.38
#    Fixed Minor issues and validation on the self checks. Updated CPU\BIOs virtualization check
# 2022-03-15 - 0.39
#    Added\Changed the Inform Alerts to be Cyan with a Black background due to Magenta did not work with the Default Blue background 
#      **Still need to expand on the wsl.exe check due to newer builds come with this file
##########################################################

## This works for Powershell v4+ to enforce Admin permissions
#Requires -RunAsAdministrator

### For Testing Purpose Only ####
#Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine

$param1=$args[0]
if ($param1 -eq $null)
{
     $param1="NOTPROVIDED"
}
 
## Script Text Coloring ###
$ScriptColor = "Yellow"
$ScriptErrors = "Red"
$ScriptInfom = "Cyan"
$ScriptBackground = "Black"

#https://docs.microsoft.com/en-us/windows/wsl/install-manual#downloading-distributions
#Distro Name     Download Endpoints       Manual Command
# Ubuntu          wslubuntu                ubuntu.exe       (Script's default Distro)
# Ubuntu 20.04    wslubuntu2004            ubuntu2004.exe
# Ubuntu 18.04    wsl-ubuntu-1804          ubuntu1804.exe
# Ubuntu 16.04    wsl-ubuntu-1604          ubuntu1604.exe   (Note this is at EOL)
# Debian          wsl-debian-gnulinux      debian.exe

## Split Script based on enable\install the Linux App from the MS Store and the after reboot to perform changes to the installed distro like degrading to WSL1
if (( $param1 -like 'install' ) -or ( $param1 -like 'part1' ))
{

####   Part1|Install   ####

#This should be enabled on HW installs, but for VM installations, Check if the Virtualization is enabled on the CPU Flags
$CPUvirtCheck = (Get-CimInstance win32_processor | Select-Object -ExpandProperty VirtualizationFirmwareEnabled)
$CPUvirtCheck2 = (gcim Win32_ComputerSystem).HypervisorPresent

if ( $CPUvirtCheck -ilike "false" -and $CPUvirtCheck2 -ilike "false" )
   {
   Write-Host "WSL can not be installed due to Virtualization is not enabled in CPU flags or BIOS" -ForegroundColor $ScriptErrors
   Exit
   }
    else {
   write-host "    Virtualization Checks completed" -ForegroundColor $ScriptInfom -BackgroundColor $ScriptBackground
   }

#Check if WSL is installed
$WSLcheck = (Test-Path -Path C:\Windows\System32\wsl.exe)

if ( $WSLcheck -ilike 'true' )
   {
   Write-Host "WSL is already installed. Please check with 'wsl -l -v' to confirm installed Distros or installation of the WSL module" -ForegroundColor $ScriptErrors
   Exit
   }


#Check Windows Build Version to determine manual install or automated install
$Build = ([System.Environment]::OSVersion.Version.Build)

if ( $Build -gt 19041 )  #If Manual install is required or wanted, change "$Build" to something like 18000 to trigger the Manual installation
{
  Write-Host "    Build version is supported with Automated WSL installation" -ForegroundColor $ScriptColor
   ## https://docs.microsoft.com/en-us/windows/wsl/install  ---Defaults to Ubuntu distro and can install another distro later (or add --d $Distro to the line below)
  wsl --install
}
 else 
  {
  Write-Host "    Build is not supported for automated installation" -ForegroundColor $ScriptColor
  Write-Host "        Performing Steps one at a time" -ForegroundColor $ScriptColor
    ## https://docs.microsoft.com/en-us/windows/wsl/install-manual
  Write-Host "    Enabling WSL Windows Feature" -ForegroundColor $ScriptColor
  dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
  Write-Host "    Enabling Virtual Machine Platform Windows Feature" -ForegroundColor $ScriptColor
  dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
  ## Download WSL Ubuntu App
  Write-Host "    Manually downloading the Linux Distro App and Installing" -ForegroundColor $ScriptColor
  curl.exe -L -o $env:USERPROFILE\Documents\wslubuntu.appx https://aka.ms/wslubuntu
  Add-AppxPackage $env:USERPROFILE\Documents\wslubuntu.appx
    #### Add Schedule Task under PowerShell to kick off the Linux distro
  $taskAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoExit Write-Host "Running the Linux Installation." -ForegroundColor Yellow; ubuntu.exe install'
  $taskTrigger = New-JobTrigger -AtLogon -RandomDelay 00:00:30
  $description = "One Time Startup kick off WSL for initialization"
    Register-ScheduledTask -TaskName "Manual_WSL_Setup_onBoot" -Action $taskAction -Trigger $taskTrigger -Description $description -RunLevel Highest –Force
  }
#Create WSL Directory to be used with the WSL<-> Windows symbolic link 
New-Item -ItemType directory -Path $env:USERPROFILE\Documents\WSL
Write-Host "    Installation complete. Reboot required and will be rebooting soon" -ForegroundColor $ScriptColor
Write-Host "  **** Please note after reboot, WSL will perform  Username\Password configurations ****" -ForegroundColor $ScriptInfom -BackgroundColor $ScriptBackground
Write-Host "  **** Once User profile is created, run the wsl install script with postinstall flag ****" -ForegroundColor $ScriptInfom -BackgroundColor $ScriptBackground
Write-Host "  **** like ./wsl_install.ps1 postinstall    this will install other programs and settings  ****" -ForegroundColor $ScriptInfom -BackgroundColor $ScriptBackground
#Reboot PC prior to running WSL for initial setup
Start-Sleep 75; Restart-Computer -Force


}
  elseif (( $param1 -like 'postinstall' ) -or ( $param1 -like 'part2' ))
 {

####   Part2|PostInstall   ####

#Reasons for opt in for WSL 1 vs WSL 2 considering performance and handling files on both Windows and WSL side
#https://docs.microsoft.com/en-us/windows/wsl/compare-versions#exceptions-for-using-wsl-1-rather-than-wsl-2
# --- Including "However, as of right now WSL 2 does not yet release cached pages in memory back to Windows until the WSL instance is shut down.
#       If you have long running WSL sessions, or access a very large amount of files, this cache can take up memory on Windows."
#   Also for networking,   
# "If you rely on a Linux distribution to have an IP address in the same network as your host machine, 
#   you may need to set up a workaround in order to run WSL 2. WSL 2 is running as a hyper-v virtual machine. 
#   This is a change from the bridged network adapter used in WSL 1, meaning that WSL 2 uses a Network Address Translation (NAT) service"

Write-Host "    Running PostInstall actions" -ForegroundColor $ScriptColor

#Self check if any WSL windows are open to convert to WSL version 1
Do {  
    $ProcessesFound = Get-Process | ? {"bash" -contains $_.Name} | Select-Object -ExpandProperty Name
    If ($ProcessesFound) {
        Write-Host "$($ProcessesFound) is still running. Please close all WSL linux Windows to proceed" -ForegroundColor $ScriptErrors
        Start-Sleep 60
    }
} Until (!$ProcessesFound)

wsl --set-version Ubuntu 1
wsl -l -v
## Checks for manual install and perform clean up if exists
$LinuxAppxcheck = (Test-Path -Path $env:USERPROFILE\Documents\wslubuntu.appx)
if ( $LinuxAppxcheck -ilike 'true' )
   {
   Write-Host "    Performing task and Manual installation file clean up" -ForegroundColor $ScriptColor
   #Remove the boot up window from tasks
   Unregister-ScheduledTask -TaskName "Manual_WSL_Setup_onBoot" -Confirm:$false
   Remove-Item $env:USERPROFILE\Documents\wslubuntu.appx
   }

## Download installer for MobaXterm for ClusterSSH
Write-Host "  Downloading MobaXterm latest version to Desktop and running installation" -ForegroundColor $ScriptColor
curl ((Invoke-WebRequest -UseBasicParsing 'https://mobaxterm.mobatek.net/download-home-edition.html').Links | Where href -like "*.zip"| Sort-Object {$null = $_.href -match "a\/MobaXterm_Installer_v\d{1,3}.\d{1,4}.zip"} -Descending | Select -Last 1|Select-Object -ExpandProperty href) -o $env:USERPROFILE\Desktop\MobaXterm.zip
Expand-Archive $env:USERPROFILE\Desktop\MobaXterm.zip -DestinationPath $env:USERPROFILE\Desktop\MobaXterm
msiexec.exe /I (Get-Item $env:USERPROFILE\Desktop\MobaXterm\*.msi | Select -First 1 -ExpandProperty FullName) /passive
### Wait for installation, and then clean up zip and unzip dir 
Write-Host "  Waiting on MobaXterm installation and then performing cleanup of zip and msi files" -ForegroundColor $ScriptColor
Start-Sleep 20; Remove-Item -Recurse $env:USERPROFILE\Desktop\MobaXterm*

##########  This is for future changes that are still in progress like deb file and potential APT repo server to house the deb install files ##########
#Save\Migrate this to the deb installer script
Write-Host "    Updating the Linux Distro APT Cache" -ForegroundColor $ScriptColor
wsl sudo apt update
#wsl sudo apt upgrade -y

 }
   else
  {
  Write-Host "Invalid parameter for WSL installation Script!" -ForegroundColor $ScriptErrors
  Write-Host " "
  Write-Host "  Please use the following parameters: " -ForegroundColor $ScriptColor
  Write-Host " "
  Write-Host " install|part1       this will perform WSL install with the selected Linux Distro" -ForegroundColor $ScriptColor
  Write-Host " postinstall|part2   this will perform after installation steps" -ForegroundColor $ScriptColor
  Exit
  }
