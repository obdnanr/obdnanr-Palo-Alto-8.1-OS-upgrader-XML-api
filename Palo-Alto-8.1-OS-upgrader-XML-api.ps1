# Palo Alto API base config upgrade 8.1.x or 9.1.x
# Version: Aplha-0.3 4/22/2020
# Written by Brandon Kelley

# Edit firewallstoupgrade.txt with 1 IP per line
# Currently there's manual Y/N for the reboot of the firewall after install for saftey reasons
# At this time.

# Future - convert the API calls into variables so it's more modular and less code
# Add more error handling and input validation
# Create more functions, so debugging will be easier
# Learn to create parallell proccessing to do multiple firewalls at the same time
# add timer for rebooting

#Ignore self signed certificate calling this script in same dir
$ignorecert = "$PSScriptRoot\ignore self signed certificate.ps1"
&$ignorecert

#text file for IPs you want to configure
$firewalList = (get-content "$PSScriptRoot\firewallstoupgrade.txt") 

#ask user for what version of code you want *need to add 2-3 code jump process via function*
$version = read-host 'version you want to go to'

function getapikey {
    # Get API Key with username and pw prompts
    param ([string]$firewallip)
    [xml]$content = Invoke-RestMethod -uri "https://$firewallip/api/?type=keygen&user=$user&password=$password"
    $content.response.result.key
}
#if there's no key hash table it'll run from here
$keys = $null
if ($keys.values -eq $null) {
    #create keys hash table
    $keys = @{ }
    #get creds
    $user = read-host 'username'
    $password = read-host 'password'
    foreach ($firewall in $firewalList) {
        #temp is to run the api function to get the key per firewall
        $temp = getapikey($firewall)
        # Add the firewall IP as the first key in hash table and the API key as a value
        $keys.Add($firewall, $temp)
    }
    #removing passwords from memory
    $user = $null
    $password = $null
}
Measure-Command {
    # Run through the $keys hash table with getenumerator
    foreach ($item in $keys.GetEnumerator()) {
        #assign the key (IP) to individual variable
        $ip = $item.Key
        #assign the hash table key's value that has the API key to individual variable
        $key = $item.Value
        #invoke license fetch using variables from above
        [xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><license><fetch></fetch></license></request>&key=$key"
        $result.response.status
        if ($result.response.status -ne "success") { write-host "failed license fetch on $ip" }
        # if the response isn't success write to screen - expand on this to provide error message or report after it runes
        #Check to see if PanOS is up to date
        [xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><system><info></info></system></show>&key=$key"
        $cursoftware = $result.SelectSingleNode("//sw-version")
        if ($cursoftware -ne "$version") {
            #Fetch available software from internet
            [xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><system><software><check></check></software></system></request>&key=$key"
            if ($result.response.status -ne "success") { write-host "failed on Fetch available software $ip" }
            $areYouUpgraded = $result.SelectSingleNode("//entry[version = ""$version""]") | Select-Object downloaded, uploaded
            if ($areYouUpgraded.downloaded -eq 'no' -and $areYouUpgraded.uploaded -eq 'no') {
                #download $version pan os *turn that into a variable*
                [xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><system><software><download><version>$version</version></download></software></system></request>&key=$key"
                $job = $result.response.result.job
                $stoploop = $result.SelectSingleNode("//job") | Select-Object status, result
                #Loop to check on PanOS downloading 
                while ($stoploop.result -ne "OK" -and $stoploop.status -ne "FIN") {
                    [xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><jobs><id>$job</id></jobs></show>&key=$key"
                    write-host $result.response.result.job.progress "% Downloading PanOS complete"
                    $stoploop = $result.SelectSingleNode("//job") | Select-Object status, result #change the status to install one
                    start-sleep -s 15
                }
            }
            Else {
                $stoploop = $null
                [xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><system><software><install><version>$version</version></install></software></system></request>&key=$key"
                $job = $result.response.result.job
               while ($stoploop.result -ne "OK" -and $stoploop.status -ne "FIN") {
                    [xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><jobs><id>$job</id></jobs></show>&key=$key"
                    write-host $result.response.result.job.progress "% complete Installing PanOS"
                    $stoploop = $result.SelectSingleNode("//job") | Select-Object status, result
                    start-sleep -s 15
                }
            }
        }
        #verify panOS insatlled
        [xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><system><software><check></check></software></system></request>&key=$key"
        #add another condition to check for uploaded also
        $areyouinstalled = $result.SelectSingleNode("//entry[version = ""$version""]") | Select-Object current, downloaded
        if ($areyouinstalled.current -eq "no" -and $areyouinstalled.downloaded -eq 'yes') {
            #!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!
            #!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!
            #!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!
            #!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!
            #!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!
            $confirm = read-host "DO YOU WANT TO REBOOT $ip? Y/N?"
            if ($confirm -eq "Y" -or $confirm -eq "y") {
                [xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><restart><system></system></restart></request>&key=$key"
                $result
                while ($cursoftware -ne "$version") {
                    #Check to see if PanOS is up to date *erroraction isn't working right fix it*
                    [xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><system><info></info></system></show>&key=$key" -ErrorAction SilentlyContinue
                    $cursoftware = $result.SelectSingleNode("//sw-version")
                    write-host "$ip is still booting"
                    start-sleep -s 15
                    if ($cursoftware.'#text' -eq "$version" -and $result.response.result -ne "Command succeeded with no output") { write-host "$ip has been upgraded" }
                }
            }
        }
        #learn parallell processing in powershell to make it do all firewalls in list at same time
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
