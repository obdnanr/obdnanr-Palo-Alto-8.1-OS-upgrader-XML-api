# Palo Alto Rest API base config upgrade 
# Version: Aplha-0.1 4/9/2020
# Written by Brandon Kelley

# Edit line 57 with a flat text file with a list of IPs that need to be upgraded.
# $firewalList = (get-content 'C:\users\me\music\firewallstoupgrade.txt')
# Connect the devices to the terminal server and mgmt to the switch.
# IP the devices *this alpha version is using DHCP, but it'll probably need to be changed to static,
# because the reboots can change the IP of the device causing it not to complete.
# Currently there's manual Y/N for the reboot of the firewall after install for saftey reasons
# At this time.

# Future - convert the rest API calls into variables so it's more modular and less code
# Add more error handling and input validation
# Create automation for setting base IP config using the terminal server
# Create more functions, so debugging will be easier
# Learn to create parallell proccessing to do multiple firewalls at the same time
# Move the ignore self signed cert stuff somewhere else
# add timer for rebooting

#ignore self signed certificate
if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type)
{
$certCallback = @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback ==null)
            {
                ServicePointManager.ServerCertificateValidationCallback +=
                    delegate
                    (
                        Object obj,
                        X509Certificate certificate,
                        X509Chain chain,
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
"@
    Add-Type $certCallback
}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
[ServerCertificateValidationCallback]::Ignore()
################################################# End - ignore self signed certificate #####################################
 
#text file for IPs you want to configure
$firewalList = (get-content 'C:\users\me\music\firewallstoupgrade.txt')

function getapikey {
# Get API Key with username and pw prompts
param ([string]$firewallip)
[xml]$content = Invoke-RestMethod -uri "https://$firewallip/api/?type=keygen&user=$user&password=$password"
$content.response.result.key
}
#if there's no key hash table it'll run from here
if ($keys.values -eq $null){
#create keys hash table
$keys = @{}
#get creds
$user = read-host 'username'
$password = read-host 'password'
foreach ($firewall in $firewalList) {
#temp is to run the api function to get the key per firewall
$temp = getapikey($firewall)
# Add the firewall IP as the first key in hash table and the API key as a value
$keys.Add($firewall,$temp)
}
#removing passwords from memory
$user = $null
$password = $null
}
Measure-Command {
# Run through the $keys hash table with getenumerator
foreach($item in $keys.GetEnumerator()){
#assign the key (IP) to individual variable
$ip = $item.Key
#assign the hash table key's value that has the API key to individual variable
$key = $item.Value
#invoke license fetch using variables from above
[xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><license><fetch></fetch></license></request>&key=$key"
$result.response.status
if ($result.response.status -ne "success"){write-host "failed license fetch on $ip"}
# if the response isn't success write to screen - expand on this to provide error message or report after it runes
#Check to see if PanOS is up to date
[xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><system><info></info></system></show>&key=$key"
$cursoftware = $result.SelectSingleNode("//sw-version")
if ($cursoftware -ne "8.1.13"){
#Fetch available software from internet
[xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><system><software><check></check></software></system></request>&key=$key"
if ($result.response.status -ne "success"){write-host "failed on Fetch available software $ip"}
$areYouUpgraded = $result.SelectSingleNode("//entry[version = ""8.1.13""]") | Select-Object downloaded,uploaded
if ($areYouUpgraded.downloaded -eq 'no' -and $areYouUpgraded.uploaded -eq 'no'){
#download 8.1.13 pan os *turn that into a variable*
[xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><system><software><download><version>8.1.13</version></download></software></system></request>&key=$key"
$job = $result.response.result.job
$stoploop = $result.SelectSingleNode("//job") | Select-Object status,result
#Loop to check on PanOS downloading #update to the install method probably won't quit loop
while ($stoploop.result -ne "FIN" -and $stoploop.status -ne "FAIL") {
[xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><jobs><id>$job</id></jobs></show>&key=$key"
write-host $result.response.result.job.progress "% Downloading PanOS complete"
$stoploop = $result.SelectSingleNode("//job") | Select-Object status,result #change the status to install one
start-sleep -s 15}
#install 8.1.13 pan os *turn that into a variable*
}
Else { [xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><system><software><install><version>8.1.13</version></install></software></system></request>&key=$key"
$job = $result.response.result.job
$stoploop = $result.SelectSingleNode("//job") | Select-Object status,result
while ($stoploop.result -ne "OK" -and $stoploop.status -ne "FIN") {
[xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><jobs><id>$job</id></jobs></show>&key=$key"
write-host $result.response.result.job.progress "% complete Installing PanOS"
$stoploop = $result.SelectSingleNode("//job") | Select-Object status,result
start-sleep -s 15}
}}
#verify panOS insatlled
[xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><system><software><check></check></software></system></request>&key=$key"
$areyouinstalled = $result.SelectSingleNode("//entry[version = ""8.1.13""]") | Select-Object current,downloaded
if ($areyouinstalled.current -eq "no" -and $areyouinstalled.downloaded -eq 'yes'){
#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!
#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!
#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!
#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!
#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!
#reboot changed IP figure it out
$confirm = read-host "DO YOU WANT TO REBOOT $ip? Y/N?"
if ($confirm -eq "Y" -or $confirm -eq "y"){
[xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><restart><system></system></restart></request>&key=$key"
$result
}}
#learn parallell processing in powershell to make it do all firewalls in list at same time
}
while ($cursoftware -ne "8.1.13"){
#Check to see if PanOS is up to date
[xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><system><info></info></system></show>&key=$key" -ErrorAction SilentlyContinue
$cursoftware = $result.SelectSingleNode("//sw-version")
write-host "$ip is still booting"
start-sleep -s 15
if ($cursoftware -eq "8.1.13" -and $result.response.result -ne "Command succeeded with no output"){write-host "$ip has been upgraded"}
}
#Reset variables for next Upgrade
$cursoftware = $null
$areyouinstalled = $null
$areYouUpgraded = $null
$job = $null
$result = $null
#finish downloading/installing app/threats/av
#add error handling
}