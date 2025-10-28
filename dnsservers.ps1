# Define target OU and DNS settings
$TargetOU = "OU=servers,DC=richamillion,DC=com" # Filter by AD server/workstation OU
$DNS1 = "192.168.1.10" # Your dns server/relay in location 1
$DNS2 = "192.168.2.10" # Your dns server/relay in location 2
$LOCATION1 = @($DNS1, $DNS2) # Primary/secondary dns server order based on location 1
$LOCATION2 = @($DNS2, $DNS1) # Primary/secondary dns server order based on location 2
$ExcludedServers = @("dnsserver1,dnsserver2,dc1,dc2") # Exclude domain controllers and any dns servers you already have set the way you want

# Grab all servers/workstations in the target OU and filter by OS excluding server you don't want to change
$Servers = Get-ADComputer -SearchBase $TargetOU -Filter * -Properties OperatingSystem | Where-Object {
    ($_.OperatingSystem -like "*Windows Server*" -or $_.OperatingSystem -like "*Windows 10*" -or $_.OperatingSystem -like "*Windows 11*") -and
    ($ExcludedServers -notcontains $_.Name)
}

# Get and set dns servers/relays based on their IP/location
foreach ($Server in $Servers) {
    $ComputerName = $Server.Name
    Write-Host "Processing $ComputerName..."

    try {
        # Get all enabled network adapters
        $Adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ComputerName $ComputerName | Where-Object { $_.IPEnabled }

        foreach ($Adapter in $Adapters) {
            # Decide DNS order based on IP prefix
            if ($Adapter.IPAddress -like '192.168.1.*') {
                $dnsOrder = $LOCATION1
            } elseif ($Adapter.IPAddress -like '192.168.2.*') {
                $dnsOrder = $LOCATION2
            } else {
                # If adapter information cannot be found, set dns order
                $dnsOrder = $LOCATION1
            }

            $result = Invoke-CimMethod -InputObject $Adapter -MethodName SetDNSServerSearchOrder -Arguments @{ DNSServerSearchOrder = $dnsOrder }
            if ($result.ReturnValue -eq 0) {
                Write-Host "DNS updated successfully on $ComputerName ($($Adapter.Description))"
            } else {
                Write-Warning "Failed to update DNS on $ComputerName ($($Adapter.Description)) (ReturnValue: $($result.ReturnValue))"
            }
        }
    } catch {
        Write-Error "Error connecting to $ComputerName"
    }
}
