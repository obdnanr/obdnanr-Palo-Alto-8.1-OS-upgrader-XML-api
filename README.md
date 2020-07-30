# What it does
Upgrade PaloAlto firewalls from 8.1.xx to 9.1.xx with PowerShell.  The firewalls will need DNS and general internet access to proceed.  It will install device licesnses.  Then it will install your requested PanOS version.  Afterwards it will install the latest App/Threats/AV Dynamic updates.  Then it will move into the next IP in the list to upgrade.

# Technologies
* Powershell 5
* PaloAlto Networks PanOS 8.1/9.1

# Recommended uses 
Rapid deployment of of firewalls to get them to a common level of PanOS.

# How to use
1) Edit firewallstoupgrade.txt with 1 IP per line
2) Run the script and enter the version you want to upgrade to
3) Enter username and password (or hard code it with default username and password)
4) Enter Y/N for the reboot of the firewall after install for saftey reasons (or remove this condition)
5) Do something else while your firewalls upgrade


# If you want to get froggy (at your own risk)
Comment lines 113-114 and remove the "}" on line 124 for set it and forget it mode.

```powershell
$confirm = read-host "DO YOU WANT TO REBOOT $ip? Y/N?"
if ($confirm -eq "Y" -or $confirm -eq "y") { 
```
