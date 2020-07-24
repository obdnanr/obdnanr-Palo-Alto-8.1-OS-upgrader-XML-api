<#$ignorecert = "$PSScriptRoot\ignore self signed certificate.ps1"
&$ignorecert
function getapikey {
    # Get API Key with username and pw prompts
    param ([string]$firewallip)
    #create keys hash table
    $keys = @{ }
    #get creds
    $user = read-host 'username'
    $password = read-host 'password'
    #removing passwords from memory
        
    [xml]$content = Invoke-RestMethod -uri "https://$firewallip/api/?type=keygen&user=$user&password=$password"
    $content.response.result.key
    $user = $null
    $password = $null
}
#>
function isjobdone {
    # Get API Key with username and pw prompts
    [cmdletbinding()]param ([string]$job, [string]$ip, [string]$key, [string]$whatareyoudoing)
    $loop = $null
    while ($loop.result -ne "OK" -and $loop.status -ne "FIN") {
        [xml]$amidone = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><jobs><id>$job</id></jobs></show>&key=$key"
        write-host $whatareyoudoing $amidone.response.result.job.progress "%"
    $loop = $amidone.response.result.job | Select-Object status, result
    if ($loop.result -eq "OK" -and $loop.status -eq "FIN") { write-host "$job job done"}
    start-sleep -s 15
    }    
}

<# testing
$ip = '192.168.0.10' 
$key = 'LUFRPT1SazNTTUFxQWxkTFVIaThnM0c1ejJzWXZqaG89T3lYZWducUR3dE9BeC8zSW9TUlF3dGNvc1pQL3pGcWZvSVQ1cW5qNnY5U1hScS9QU3NSRk5WRWdFOEpITENLaA=='

        #download AV
        [xml]$resultavdl = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><anti-virus><upgrade><download><latest/></download></upgrade></anti-virus></request>&key=$key"
        $job = $resultavdl.response.result.job
        try { isjobdone -job $job -ip $ip -key $key -whatareyoudoing 'Downloading AV'
        }
        catch { if($resultavdl.response.msg.line -ne $null){write-host $resultavdl.response.msg.line}}
             

#$key = getapikey -firewallip 192.168.0.10

#isjobdone -job '781' -ip '192.168.0.10' -key 'LUFRPT1SazNTTUFxQWxkTFVIaThnM0c1ejJzWXZqaG89T3lYZWducUR3dE9BeC8zSW9TUlF3dGNvc1pQL3pGcWZvSVQ1cW5qNnY5U1hScS9QU3NSRk5WRWdFOEpITENLaA=='


<#
$stoploop3 = $null
[xml]$resultapp = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<request><content><upgrade><download><latest/></download></upgrade></content></request></request>&key=$key"
$job = $resultapp.response.result.job
while ($stoploop3.result -ne "OK" -and $stoploop3.status -ne "FIN") {
    [xml]$resultapp = Invoke-RestMethod -method Get -uri "https://$ip/api/?type=op&cmd=<show><jobs><id>$job</id></jobs></show>&key=$key"
    $stoploop3 = $resultapp.response.result.job | Select-Object status, result
    if ($stoploop3.result -ne "OK" -and $stoploop3.status -ne "FIN") { write-host $resultapp.response.result.job.progress "% complete downloading app/threats" }
    if ($stoploop3.result -eq "OK" -and $stoploop3.status -eq "FIN") { write-host "downloaded apps" }
    start-sleep -s 15
#>
#>