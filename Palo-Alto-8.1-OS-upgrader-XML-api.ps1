# Palo Alto API base config upgrade 8.1.x or 9.1.x
# Version: Aplha-0.4 7/23/2020
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
        [xml]$resultsysteminfo = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><system><info></info></system></show>&key=$key"
        $cursoftware = $resultsysteminfo.SelectSingleNode("//sw-version")
        if ($cursoftware.'#text' -ne "$version") {
            #Fetch available software from internet
            [xml]$resultsoft = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><system><software><check></check></software></system></request>&key=$key"
            if ($resultsoft.response.status -ne "success") { write-host "failed on Fetch available software $ip" }
            $areYouUpgraded = $resultsoft.SelectSingleNode("//entry[version = ""$version""]") | Select-Object downloaded
            if ($areYouUpgraded.downloaded -eq 'no') {
                #download $version pan os *turn that into a variable*
                [xml]$resultdl = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><system><software><download><version>$version</version></download></software></system></request>&key=$key"
                $job = $resultdl.response.result.job
                $stoploop = $null 
                #Loop to check on PanOS downloading
                while ($stoploop.result -ne "OK" -and $stoploop.status -ne "FIN") {
                    [xml]$resultdl = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><jobs><id>$job</id></jobs></show>&key=$key"
                    $stoploop = $resultdl.response.result.job | Select-Object status, result #change the status to install one
                    if ($stoploop.result -ne "OK" -and $stoploop.status -ne "FIN") { write-host $resultdl.response.result.job.progress "% Downloading PanOS complete" }
                    if ($stoploop.result -eq "OK" -and $stoploop.status -eq "FIN") { write-host "$version downloaded" }                   
                    start-sleep -s 15
                }
            }
            Else {
                $stoploop2 = $null
                # install $version that's downloaded
                [xml]$resultinstall = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><system><software><install><version>$version</version></install></software></system></request>&key=$key"
                $job = $resultinstall.response.result.job
                while ($stoploop2.result -ne "OK" -and $stoploop2.status -ne "FIN") {
                    [xml]$resultinstall = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><jobs><id>$job</id></jobs></show>&key=$key"
                    $stoploop2 = $resultinstall.response.result.job | Select-Object status, result
                    if ($stoploop2.result -ne "OK" -and $stoploop2.status -ne "FIN") { write-host $resultinstall.response.result.job.progress "% complete Installing PanOS" }
                    if ($stoploop2.result -eq "OK" -and $stoploop2.status -eq "FIN") { write-host "$ip has installed $version.  Moving to reboot" }                   
                    start-sleep -s 15
                }
            }
        }
        #verify panOS installed
        [xml]$resultinstalled = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><system><software><check></check></software></system></request>&key=$key"
        #add another condition to check for uploaded also
        $areyouinstalled = $resultinstalled.SelectSingleNode("//entry[version = ""$version""]") | Select-Object current, downloaded
        if ($areyouinstalled.current -eq "no" -and $areyouinstalled.downloaded -eq 'yes') {
            #!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!
            #!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!
            #!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!
            #!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!
            #!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!
            $confirm = read-host "DO YOU WANT TO REBOOT $ip? Y/N?"
            if ($confirm -eq "Y" -or $confirm -eq "y") {
                [xml]$resultreboot = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><restart><system></system></restart></request>&key=$key"
                $resultreboot
                while ($cursoftware -ne "$version") {
                    #Check to see if PanOS is up to date *erroraction isn't working right fix it*
                    [xml]$resultfin = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><system><info></info></system></show>&key=$key" -ErrorAction SilentlyContinue
                    $cursoftware = $resultfin.SelectSingleNode("//sw-version")
                    write-host "$ip is still booting"
                    start-sleep -s 15
                    if ($cursoftware.'#text' -eq "$version" -and $result.response.result -ne "Command succeeded with no output") { write-host "$ip has been upgraded" }
                }
            }
        }
        #download apps/threats
        $stoploop3 = $null
        [xml]$resultapp = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><content><upgrade><download><latest/></download></upgrade></content></request></request>&key=$key"
        $job = $resultapp.response.result.job
        while ($stoploop3.result -ne "OK" -and $stoploop3.status -ne "FIN") {
            [xml]$resultapp = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><jobs><id>$job</id></jobs></show>&key=$key"
            $stoploop3 = $resultapp.response.result.job | Select-Object status, result
            if ($stoploop3.result -ne "OK" -and $stoploop3.status -ne "FIN") { write-host $resultapp.response.result.job.progress "% complete downloading app/threats" }
            if ($stoploop3.result -eq "OK" -and $stoploop3.status -eq "FIN") { write-host "downloaded apps" }
            start-sleep -s 15
        }
        #install apps
        $stoploop4 = $null
        [xml]$resultappins = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><content><upgrade><install><version>latest</version></install></upgrade></content></request>&key=$key"
        $job = $resultappins.response.result.job
        while ($stoploop4.result -ne "OK" -and $stoploop4.status -ne "FIN") {
            [xml]$resultappins = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><jobs><id>$job</id></jobs></show>&key=$key"
            $stoploop4 = $resultappins.response.result.job | Select-Object status, result
            if ($stoploop4.result -ne "OK" -and $stoploop4.status -ne "FIN") { write-host $resultappins.response.result.job.progress "% complete installing app/threats" }
            if ($stoploop4.result -eq "OK" -and $stoploop4.status -eq "FIN") { write-host "installed apps" }
            start-sleep -s 15
        }
        #download AV
        $stoploop5 = $null
        [xml]$resultavdl = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><anti-virus><upgrade><download><latest/></download></upgrade></anti-virus></request>&key=$key"
        $job = $resultavdl.response.result.job
        while ($stoploop5.result -ne "OK" -and $stoploop5.status -ne "FIN") {
            [xml]$resultavdl = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><jobs><id>$job</id></jobs></show>&key=$key"
            $stoploop5 = $resultavdl.response.result.job | Select-Object status, result
            if ($stoploop5.result -ne "OK" -and $stoploop5.status -ne "FIN") { write-host $resultavdl.response.result.job.progress "% complete downloading av" }
            if ($stoploop5.result -eq "OK" -and $stoploop5.status -eq "FIN") { write-host "downloaded av" }
            start-sleep -s 15
        }
        #install av
        $stoploop6 = $null
        [xml]$resultavins = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><anti-virus><upgrade><download><latest/></download></upgrade></anti-virus></request>&key=$key"
        $job = $resultavins.response.result.job
        while ($stoploop6.result -ne "OK" -and $stoploop6.status -ne "FIN") {
            [xml]$resultavins = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><jobs><id>$job</id></jobs></show>&key=$key"
            $stoploop5 = $resultavins.response.result.job | Select-Object status, result
            if ($stoploop6.result -ne "OK" -and $stoploop6.status -ne "FIN") { write-host $resultavins.response.result.job.progress "% installing av" }
            if ($stoploop6.result -eq "OK" -and $stoploop6.status -eq "FIN") { write-host "installed av" }
            start-sleep -s 15
        }                     
    }
}
#Reset variables for next Upgrade
<#
    $cursoftware = $null
    $areyouinstalled = $null
    $areYouUpgraded = $null
    $job = $null
    $result = $null
    #>
#add error handling
