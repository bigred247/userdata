"<powershell>
Write-Host ""Setting the Proxy for EC2 API Calls""
Set-AWSProxy -Hostname mgmt-clearos.mtcnovo.net -Port 3128 -ByPassList 169.254.169.254 

Write-Host ""Get EC2 Instance Name""
$InstanceId = (Invoke-RestMethod 'http://169.254.169.254/latest/meta-data/instance-id').ToString()
$AvailabilityZone = (Invoke-RestMethod 'http://169.254.169.254/latest/meta-data/placement/availability-zone').ToString()
$Region = $AvailabilityZone.Substring(0,$AvailabilityZone.Length-1)
$Tags = Get-EC2Tag -Filters @{Name='resource-id';Value=$InstanceId} -Region $Region
$InstanceName = ($Tags | Where-Object {$_.Key -eq 'Name'}).Value
Write-Host ""Found Instance Name: $InstanceName""

Write-Host ""Setting AD Credentials""
$username = ""SVC_DOM_JOIN@mtcnovo.net""
$password = ""Gl0bal199@"" | ConvertTo-SecureString -AsPlainText -Force
$cred = New-Object -typename System.Management.Automation.PSCredential($username, $password)

Write-Host ""Renaming and Joining the Domain""
Rename-Computer -NewName $instanceName -Force
Start-Sleep -s 5
Add-Computer -DomainName mtcnovo.net -Options JoinWithNewName,AccountCreate -Credential $cred -Force
Write-Host ""Disabling NetBios over TCP/IP""
set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\services\NetBT\Parameters\Interfaces\tcpip* -Name NetbiosOptions -Value 2
Restart-Computer -Force
</powershell>"