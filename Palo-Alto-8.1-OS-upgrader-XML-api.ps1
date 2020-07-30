<###### Working Alpha #######
Palo Alto API base config upgrade 8.1.x or 9.1.x
Version: Aplha-1.0 7/30/2020
Written by Brandon Kelley

######  How to use  ######
Edit firewallstoupgrade.txt with 1 IP per line
Run the script and under the version you want to upgrade to
Enter username and password
Enter Y/N for the reboot of the firewall after install for saftey reasons (or remove this condition)
Do something else while your firewalls upgrade

###### Future improvements ######
Create parallel proccessing to do multiple firewalls at the same time
Input validation
Add function error streams 
Make it more modular
#>

#Ignore self signed certificate calling this script in same dir
$ignorecert = "$PSScriptRoot\ignore self signed certificate.ps1"
&$ignorecert

# Edit this text file for IPs you want to upgrade
$firewalList = (get-content "$PSScriptRoot\firewallstoupgrade.txt")
write-host "Upgrading these firewalls:"
$firewalList
# Ask what version of code you want # need to add 2-3 code jump
$version = read-host 'version you want to go to'

function getapikey {
    # Get API Key with username and pw prompts
    param ([string]$firewallip)
    [xml]$content = Invoke-RestMethod -uri "https://$firewallip/api/?type=keygen&user=$user&password=$password"
    $content.response.result.key
}

# Check if the job complete 
function isjobdone {
    [cmdletbinding()]param ([string]$job, [string]$ip, [string]$key, [string]$whatareyoudoing)
    $loop = $null
    while ($loop.result -ne "OK" -and $loop.status -ne "FIN") {
        [xml]$amidone = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><jobs><id>$job</id></jobs></show>&key=$key"
        write-host $whatareyoudoing $amidone.response.result.job.progress "%"
        $loop = $amidone.response.result.job | Select-Object status, result
        # Write out error message from API call
        if ($amidone.response.msg.line -ne $null) {
            write-host $amidone.response.msg.line
            $loop.result = "OK" #needs testing
            $loop.status = "FIN"
        }
        # Check if job has finished
        if ($loop.result -eq "OK" -and $loop.status -eq "FIN") { write-host "$job job done" }
        start-sleep -s 15
    }    
}

# If there's no keys hash table it'll run from here
$keys = $null
if ($keys.values -eq $null) {
    # Create hash table
    $keys = @{ }
    # Get creds
    $user = read-host 'username'
    $password = read-host 'password'
    foreach ($firewall in $firewalList) {
        # Temp is to hold the api key per firewall
        $temp = getapikey($firewall)
        # Add the firewall IP as the first key in hash table and the API key the second value
        $keys.Add($firewall, $temp)
    }
    # Removing passwords from memory
    $user = $null
    $password = $null
}
Measure-Command {
    # Run through the $keys hash table with getenumerator
    foreach ($item in $keys.GetEnumerator()) {
        # Assign the key (IP) to individual variable
        $ip = $item.Key
        # Assign the hash table key's value that has the API key to individual variable
        $key = $item.Value
        # Fetch licenses
        [xml]$result = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><license><fetch></fetch></license></request>&key=$key"
        $result.response.status
        if ($result.response.status -ne "success") { write-host "failed license fetch on $ip" }
        # Check to see if PanOS is up to date
        [xml]$resultsysteminfo = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><system><info></info></system></show>&key=$key"
        $cursoftware = $resultsysteminfo.SelectSingleNode("//sw-version")
        if ($cursoftware.'#text' -ne "$version") {
            # Fetch available software from internet
            [xml]$resultsoft = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><system><software><check></check></software></system></request>&key=$key"
            if ($resultsoft.response.status -ne "success") { write-host "failed on Fetch available software $ip" }
            $areyoudownloaded = $resultsoft.SelectSingleNode("//entry[version = ""$version""]") | Select-Object downloaded, current
            if ($areyoudownloaded.current -eq 'no') {
                # Download requested PanOS version
                if ($areyoudownloaded.downloaded -eq 'no') {
                    [xml]$resultdl = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><system><software><download><version>$version</version></download></software></system></request>&key=$key"
                    $job = $resultdl.response.result.job
                    isjobdone -job $job -ip $ip -key $key -whatareyoudoing "Downloading PanOS"
                }            
                # Install requested version that's downloaded
                if ($areyoudownloaded.downloaded -eq 'yes') {
                    [xml]$resultinstall = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><system><software><install><version>$version</version></install></software></system></request>&key=$key"
                    $job = $resultinstall.response.result.job
                    isjobdone -job $job -ip $ip -key $key -whatareyoudoing "Installing Panos"
                    write-host "$ip has installed $version.  Moving to reboot" 
                }
            }
            if ($resultinstall.response.status -eq "success") {
                #!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!
                #!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!#!!!!!!!!!!!!!!!!!!!DANGER OPERATIONAL COMMAND TO REBOOT!!!!!!!!!!!!!
                $confirm = read-host "DO YOU WANT TO REBOOT $ip? Y/N?"
                if ($confirm -eq "Y" -or $confirm -eq "y") {
                    [xml]$resultreboot = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><restart><system></system></restart></request>&key=$key"
                    $resultreboot.response.status
                    while ($areyouinstalled.'#text' -ne "$version") {
                        # Check to see if PanOS is up to date *erroractions are still showing errors*
                        [xml]$resultfin = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><system><info></info></system></show>&key=$key" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -InformationAction SilentlyContinue
                        $areyouinstalled = $resultfin.SelectSingleNode("//sw-version")
                        write-host "$ip is still booting"
                        if ($areyouinstalled.'#text' -eq "$version") { write-host "$ip has been upgraded" }
                        start-sleep -s 60
                    }
                }
            }
            # Download Apps/Threats
            [xml]$resultapp = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><content><upgrade><download><latest/></download></upgrade></content></request>&key=$key"
            $job = $resultapp.response.result.job
            isjobdone -job $job -ip $ip -key $key -whatareyoudoing "Download apps/threats"
        
            # Install Apps/Threats
            [xml]$resultappins = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><content><upgrade><install><version>latest</version></install></upgrade></content></request>&key=$key"
            $job = $resultappins.response.result.job
            isjobdone -job $job -ip $ip -key $key -whatareyoudoing "Installing apps/threats"
        
            # Download AV
            [xml]$resultavdl = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><anti-virus><upgrade><download><latest/></download></upgrade></anti-virus></request>&key=$key"
            $job = $resultavdl.response.result.job
            isjobdone -job $job -ip $ip -key $key -whatareyoudoing "Downloading AV"
        
            # Install AV
            [xml]$resultavins = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><anti-virus><upgrade><download><latest/></download></upgrade></anti-virus></request>&key=$key"
            $job = $resultavins.response.result.job
            isjobdone -job $job -ip $ip -key $key -whatareyoudoing "Installing AV"
        }
    }
}