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

Write-Host ""Disabling SMB v1""
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force

Write-Host ""Set Time Zone to GMT""
tzutil /s ""GMT Standard Time""

Write-Host ""Installing Trend""
[Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
$env:LogPath = ""$env:appdata\Trend Micro\Deep Security Agent\installer""
New-Item -path $env:LogPath -type directory
Start-Transcript -path ""$env:LogPath\dsa_deploy.log"" -append
echo ""$(Get-Date -format T) - DSA download started""
(New-Object System.Net.WebClient).DownloadFile(""https://mgmt-trend.mtcnovo.net:443/software/agent/Windows/x86_64/"", ""$env:temp\agent.msi"")
echo ""$(Get-Date -format T) - Downloaded File Size:"" (Get-Item ""$env:temp\agent.msi"").length
echo ""$(Get-Date -format T) - DSA install started""
echo ""$(Get-Date -format T) - Installer Exit Code:"" (Start-Process -FilePath msiexec -ArgumentList ""/i $env:temp\agent.msi /qn ADDLOCAL=ALL /l*v `""$env:LogPath\dsa_install.log`"""" -Wait -PassThru).ExitCode 
echo ""$(Get-Date -format T) - DSA activation started""
Start-Sleep -s 20
& $Env:ProgramFiles""\Trend Micro\Deep Security Agent\dsa_control"" -r
& $Env:ProgramFiles""\Trend Micro\Deep Security Agent\dsa_control"" -a dsm://mgmt-trend.mtcnovo.net:4120/ ""policyid:20""
Stop-Transcript
echo ""$(Get-Date -format T) - DSA Deployment Finished""

Write-Host ""Installing ALM Agent""
$env:LogPath = ""$env:temp""
Start-Transcript -path ""$env:LogPath\alm_deploy.log"" -append
echo ""$(Get-Date -format T) - ALM download started""
(New-Object System.Net.WebClient).DownloadFile(""http://mtc-lon-repo-testing.s3.amazonaws.com/agents/Assuria_Log_Manager_Agent-4.5.21-x64.msi"", ""$env:temp\Assuria_Log_Manager_Agent-4.5.21-x64.msi"")
echo ""$(Get-Date -format T) - Downloaded File Size:"" (Get-Item ""$env:temp\Assuria_Log_Manager_Agent-4.5.21-x64.msi"").length
(New-Object System.Net.WebClient).DownloadFile(""http://mtc-lon-repo-testing.s3.amazonaws.com/agents/assuria.mst"", ""$env:temp\assuria.mst"")
echo ""$(Get-Date -format T) - Downloaded File Size:"" (Get-Item ""$env:temp\assuria.mst"").length
echo ""$(Get-Date -format T) - ALM install started""
echo ""$(Get-Date -format T) - Installer Exit Code:"" (Start-Process -FilePath msiexec -ArgumentList ""/i $env:temp\Assuria_Log_Manager_Agent-4.5.21-x64.msi TRANSFORMS=$env:temp\assuria.mst /quiet"" -Wait -PassThru).ExitCode 
echo ""$(Get-Date -format T) - ALM Deployment Finished""

Write-Host ""Sleeping to allow agent updates""
Start-Sleep -s 60

Restart-Computer -Force
</powershell>"