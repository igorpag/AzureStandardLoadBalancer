#region Check PowerShell modules

# Check PowerShell module versions: #
$module_names='AzureRM*' 
if(Get-Module -ListAvailable |  
    Where-Object { $_.name -clike $module_names })  
{  
    (Get-Module -ListAvailable | Where-Object{ $_.Name -clike $module_names }) |  
    Select Version, Name, Author, PowerShellVersion  | Format-Table 
}  
else  
{  
    “The Azure PowerShell module is not installed.” 
}
#endregion Check PowerShell modules

#region Initialize global variables for the script #
#
# PLEASE replace parameter placeholders with your own values #
#
$mySubscriptionID = '<<....>>'
$mySubscriptionName = '<<....>>'
$VMpwd = '<<....>>' 
$VMuser = '<<....>>'
$rgname = '<<....>>' 
$location = '<<....>>'
$storageacccountname = '<<....>>'
$VNETname = "Vnet1"
$ILPIP1name = "ilpip1"
$ILPIP2name = "ilpip2"
$domainlabel = '<<....>>'
$domainlabel2 = '<<....>>'
$feName = "LB-Frontend1"
$feName2 = "LB-Frontend2"
$feName3 = "LB-Frontend3"
$beName = "LB-backend1"
$beName2 = "LB-backend2"
$beName3 = "LB-backend3"
$NICname = "nic1"
$NICname2 = "nic2"
$NICname3 = "nic3"
$NICname4= "nic4"
$ipconfigname = "IPConfig-1"
$ipconfigname2 = "IPConfig-2"
$ipconfigname3 = "IPConfig-3"
$ipconfigname4 = "IPConfig-4"
$subnetname = "Subnet1"
$subnetname2 = "Subnet2"
$subnetname3 = "Subnet3"
$VMSize = "Standard_DS1_v2"
$VMName = '<<....>>'
$VMName2 = '<<....>>'
$VMName3 = '<<....>>'
$VMName4 = '<<....>>'
$zonenumber = 1
$zonenumber2 = 2
$zonenumber3 = 3
$externalport = 28492
$NSGname = "NSG-1"
$ILBname = "ILB-1"
$SLBname = "SLB-1"

#endregion Initialize global variables for the script #

#region Login and select subscription #
Login-AzureRmAccount
Get-AzureRmSubscription –SubscriptionName $mySubscriptionName | Set-AzureRmContext
Get-AzureRMContext
#endregion Login and select subscription #

#region Create global resources and Resource Group #
New-AzureRmResourceGroup -Name $rgname -Location $location

# Create  storage account and set as default: #
$StorageAccount = New-AzureRmStorageAccount -ResourceGroupName $rgname -Name $storageacccountname -Type Standard_LRS -Location $location
Set-AzureRmCurrentStorageAccount –ResourceGroupName $rgname –StorageAccountName $storageacccountname
# Check current defaults: #
Get-AzureRmContext -Verbose

# Create Subnets and VNET #
$subnet1 = New-AzureRmVirtualNetworkSubnetConfig -Name 'Subnet1' -AddressPrefix '10.1.1.0/24'
$subnet2 = New-AzureRmVirtualNetworkSubnetConfig -Name 'Subnet2' -AddressPrefix '10.1.2.0/24'
$subnet3 = New-AzureRmVirtualNetworkSubnetConfig -Name 'Subnet3' -AddressPrefix '10.1.3.0/24'
$vnet = New-AzureRmVirtualNetwork -Name $VNETname -ResourceGroupName $rgname -Location $location -AddressPrefix '10.1.0.0/16' -Subnet $subnet1,$subnet2,$subnet3

# Select OS Image for Windows VM: #
$publisher = (Get-AzureRmVMImagePublisher -Location $location |? PublisherName -like "MicrosoftWindowsServer").PublisherName
$offer = (Get-AzureRmVMImageOffer -Location $location -PublisherName $publisher | ? Offer -EQ "WindowsServer").Offer
$sku = (Get-AzureRmVMImageSku -Location $location -Offer $offer -PublisherName $publisher | ? Skus -EQ "2016-Datacenter").Skus
$imageid = (Get-AzureRmVMImage -Location $location -Offer $offer -PublisherName $publisher -Skus $sku | Sort Version -Descending)[0].Id
$version = (Get-AzureRmVMImage -Location $location -Offer $offer -PublisherName $publisher -Skus $sku | Sort Version -Descending)[0].Version

# Check Azure quotas for compute and storage: #
Get-AzureRmVMUsage $location -Verbose
Get-AzureRmStorageUsage 

#endregion Create global resources and Resource Group #

#region SAMPLE[1]: Create a simple zoned VM with an instance level STANDARD IP

# Create a Public IP
$ilpip1 = New-AzureRmPublicIpAddress -ResourceGroupName $rgname -Name $ILPIP1name -Location $location -AllocationMethod "Static" -IpAddressVersion IPv4 `
            -Sku Standard -DomainNameLabel $domainlabel
$fqdn = $ilpip1.DnsSettings.Fqdn # For example: <<xxxxxxxxxx>>.westeurope.cloudapp.azure.com
$ip = $ilpip1.IpAddress # Please note that is statically assigned, then immediately allocated at creation time
$subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $subnetname -VirtualNetwork $vnet

# Create a NIC #
$ipconfig1 = New-AzureRmNetworkInterfaceIpConfig -Name $ipconfigname -Subnet $subnet -PublicIpAddress $ilpip1 -Primary
$nic1 = New-AzureRmNetworkInterface -ResourceGroupName $rgname -Location $location -Name $NICname -IpConfiguration $ipConfig1

# Create the main VM object: #
$OSDiskName = $VMName + "-osDisk"
# Credentials
$SecurePassword = ConvertTo-SecureString $VMpwd -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($VMuser, $SecurePassword); 
# Create VM Config #
# Please note that no Availability Set has been specified since I will use Availability Zones (AZ): #
$VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize -Zone $zonenumber
$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName $publisher -Offer $offer -Skus $sku -Version "latest"
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $nic1.Id -Primary
# Set the OS disk to be a Managed Disk #
$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -CreateOption FromImage -Caching ReadWrite `
    -DiskSizeInGB 128 -StorageAccountType StandardLRS -Windows
$VM1 = New-AzureRmVM -ResourceGroupName $rgname -Location $Location -VM $VirtualMachine

# Now try to connect using RDP:
$machinename = $ip
Start-Process "$env:windir\system32\mstsc.exe" -ArgumentList "/v:$machinename"
# You will fail because there is no NSG associated to the STANDARD Public IP!

# Now let's fix the connectivity adding NSG rule as expected.... #

# Create NSG to assign to the specific NIC for port 3389 (RDP)
$rule1 = New-AzureRmNetworkSecurityRuleConfig -Name "rdp-rule" -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 `
    -SourceAddressPrefix Internet -SourcePortRange * -DestinationPortRange 3389 -DestinationAddressPrefix *
$nsg1 = New-AzureRmNetworkSecurityGroup -ResourceGroupName $rgname -Location $location -Name $NSGname -SecurityRules $rule1
# Apply NSG to specific VM NIC: #
$nic1.NetworkSecurityGroup = $nsg1
$nic1 | Set-AzureRmNetworkInterface

# Now wait some seconds, then try to connect using RDP again, with NSG in place, you will SUCCEED! #
Start-Sleep -Seconds 30
Start-Process "$env:windir\system32\mstsc.exe" -ArgumentList "/v:$machinename"

#endregion SAMPLE[1]: Create a zoned VM with an instance level STANDARD IP

#region SAMPLE[2]: Create a STANDARD LB with 2 zoned VMs behind it #
$vnet = Get-AzureRmVirtualNetwork -Name $VNETname -ResourceGroupName $rgname 
$subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $subnetname2 -VirtualNetwork $vnet

$ilpip2 = New-AzureRmPublicIpAddress -ResourceGroupName $rgname -Name $ILPIP2name -Location $location -AllocationMethod "Static" -IpAddressVersion IPv4 `
            -Sku Standard -DomainNameLabel $domainlabel2
$fqdn = $ilpip2.DnsSettings.Fqdn # For example: <<XXXXXXXX>>.westeurope.cloudapp.azure.com
$ip = $ilpip1.IpAddress # Please note that is statically assigned, then immediately allocated at creation time 

# Please note that in the cmdlet below I did NOT specify a value for the "Zone" parameter since I want it zone-resilient across all zones. #
$feIP = New-AzureRmLoadBalancerFrontendIpConfig -Name $feName2 -PublicIpAddress $ilpip2
$bePOOL= New-AzureRmLoadBalancerBackendAddressPoolConfig -Name $beName2

# Now create LB rule for simple test for RDP access, no NAT rule crated in this case: #
$lbrule = New-AzureRmLoadBalancerRuleConfig -Name "RDP" -FrontendIpConfiguration $feIP -BackendAddressPool  $bePOOL -FrontendPort $externalport -BackendPort 3389

# Now create the LB with STANDARD SKU type specified: #
$SLB = New-AzureRmLoadBalancer -ResourceGroupName $rgname -Name $SLBname -Location $location -FrontendIpConfiguration $feIP -LoadBalancingRule $lbrule `
        -BackendAddressPool $bePOOL -Sku Standard

# Now create NIC and VM in the LB backend pool: #
$ipconfig2 = New-AzureRmNetworkInterfaceIpConfig -Name $ipconfigname2 -Subnet $subnet -Primary -LoadBalancerBackendAddressPool $SLB.BackendAddressPools[0]
$nic2 = New-AzureRmNetworkInterface -ResourceGroupName $rgname -Location $location -Name $NICname2 -IpConfiguration $ipConfig2
            
# Now create a new VM and attach this NIC just created: #
# Create the main VM object: #
$VMName = $VMName2
$OSDiskName = $VMName + "-osDisk"
# Credentials
$SecurePassword = ConvertTo-SecureString $VMpwd -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($VMuser, $SecurePassword); 
# Create VM Config #
# Please note that no Availability Set has been specified since I will use Availability Zones (AZ): #
$VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize -Zone $zonenumber
$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName $publisher -Offer $offer -Skus $sku -Version "latest"
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $nic2.Id -Primary
# Set the OS disk to be a Managed Disk #
$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -CreateOption FromImage -Caching ReadWrite `
    -DiskSizeInGB 128 -StorageAccountType StandardLRS -Windows
$VM2 = New-AzureRmVM -ResourceGroupName $rgname -Location $Location -VM $VirtualMachine

#### TEST: If you now try to access the VM, you will fail because as in the previous example, there is no NSG associated!
# Try to connect now:
$ilpip2.IpAddress 
$lbrule.FrontendPort 
$port = $lbrule.FrontendPort
$machinename = ($ilpip2.IpAddress + ":" + "$port")
Start-Process "$env:windir\system32\mstsc.exe" -ArgumentList "/v:$machinename"

# Create a new NSG and set at subnet level (Subnet2): #
$rdpRule = New-AzureRmNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" -Access Allow `
       -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
$networkSecurityGroup = New-AzureRmNetworkSecurityGroup -ResourceGroupName $rgname `
       -Location $vnet.Location -Name "NSGruleRDP" -SecurityRules $rdpRule
Set-AzureRmVirtualNetworkSubnetConfig -Name $subnet.Name -NetworkSecurityGroup $networkSecurityGroup -VirtualNetwork $vnet -AddressPrefix "10.1.2.0/24"
$vnet | Set-AzureRmVirtualNetwork

#### TEST: Try again and should succeed!
Start-Sleep -Seconds 30
Start-Process "$env:windir\system32\mstsc.exe" -ArgumentList "/v:$machinename"

# Now create a second NIC and a second VM in the LB backend pool, but different ZONE, logically still in the same subnet and VNET : #
$ipconfig3 = New-AzureRmNetworkInterfaceIpConfig -Name $ipconfigname3 -Subnet $subnet -Primary -LoadBalancerBackendAddressPool $SLB.BackendAddressPools[0]
$nic3 = New-AzureRmNetworkInterface -ResourceGroupName $rgname -Location $location -Name $NICname3 -IpConfiguration $ipconfig3
        
# Now create a new VM and attach this NIC just created: #
# Create the main VM object: #
$VMName = $VMName3
$OSDiskName = $VMName + "-osDisk"
# Credentials
$SecurePassword = ConvertTo-SecureString $VMpwd -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($VMuser, $SecurePassword); 
# Create VM Config #
# Please note that no Availability Set has been specified since I will use Availability Zones (AZ): #
$VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize -Zone $zonenumber2
$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName $publisher -Offer $offer -Skus $sku -Version "latest"
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $nic3.Id -Primary
# Set the OS disk to be a Managed Disk #
$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -CreateOption FromImage -Caching ReadWrite `
    -DiskSizeInGB 128 -StorageAccountType StandardLRS -Windows
$VM3 = New-AzureRmVM -ResourceGroupName $rgname -Location $Location -VM $VirtualMachine

#### TEST: Now stop the previous VM in ZONE1 and check il LB will redirect now to the new VM in ZONE2 transparently: #

Stop-AzureRmVM -ResourceGroupName $rgname -Name $VMName2 -Force
# Wait 30 seconds for the LB to detect VM2 in ZONE1 is down
Start-Sleep -Seconds 30
# Now try to connect to VM3 in ZONE2, please note that assignment to "$machinename" did not change, still pointing to the previous Public IP assigned to the LB: #
Start-Process "$env:windir\system32\mstsc.exe" -ArgumentList "/v:$machinename"
# Inside the VM, check for the VM name to ensure you landed in the correct VM #

#endregion SAMPLE[2]: Create a STANDARD LB with 2 zoned VMs behind it #

#region SAMPLE[3]: Create a STANDARD internal LB with HA Port feature configured and 1 zoned VM behind it #
$vnet = Get-AzureRmVirtualNetwork -Name $VNETname -ResourceGroupName $rgname 
$subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $subnetname3 -VirtualNetwork $vnet
$feIP = New-AzureRmLoadBalancerFrontendIpConfig -Name $feName3 -PrivateIpAddress "10.1.3.200" -SubnetId $subnet.Id
$bePOOL= New-AzureRmLoadBalancerBackendAddressPoolConfig -Name $beName3

# Create a LB rule for HA port: all ports will be forwarded to the VMs behind the LB! #
$lbrule = New-AzureRmLoadBalancerRuleConfig -Name "HAPortsLBrule" -FrontendIpConfiguration $feIP -BackendAddressPool $bePOOL `
            -Protocol "All" -FrontendPort 0 -BackendPort 0 #-DisableOutboundSNAT
# Please note the usage and values for the last 3 parameters in the previous cmdlet....

#Create the internal LB with HA Port rule: #
$ILB = New-AzureRmLoadBalancer -ResourceGroupName $rgname -Name $ILBname -Location $location -FrontendIpConfiguration $feIP `
            -LoadBalancingRule $lbrule -BackendAddressPool $bePOOL -Sku Standard 

# Now create a single VM behind it and check that even without any specific port rule, access will be allowed: #
$ipconfig4 = New-AzureRmNetworkInterfaceIpConfig -Name $ipconfigname4 -Subnet $subnet -Primary -LoadBalancerBackendAddressPool $ILB.BackendAddressPools[0]
$nic4 = New-AzureRmNetworkInterface -ResourceGroupName $rgname -Location $location -Name $NICname4 -IpConfiguration $ipconfig4
       
# Now create a new VM and attach this NIC just created: #
# Create the main VM object: #
$VMName = $VMName4
$OSDiskName = $VMName + "-osDisk"
# Credentials
$SecurePassword = ConvertTo-SecureString $VMpwd -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($VMuser, $SecurePassword); 
# Create VM Config #
# Please note that no Availability Set has been specified since I will use Availability Zones (AZ): #
$VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize -Zone $zonenumber3
$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName $publisher -Offer $offer -Skus $sku -Version "latest"
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $nic4.Id -Primary
# Set the OS disk to be a Managed Disk #
$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -CreateOption FromImage -Caching ReadWrite `
    -DiskSizeInGB 128 -StorageAccountType StandardLRS -Windows
$VM4 = New-AzureRmVM -ResourceGroupName $rgname -Location $Location -VM $VirtualMachine

# In order to test connectivity, use the first VM created in SAMPLE[1] as a Jum-Box to connect to this new VM, behind internal LB, using RDP: #

$ilpip1 = Get-AzureRmPublicIpAddress -ResourceGroupName $rgname -Name $ILPIP1name
$fqdn = $ilpip1.DnsSettings.Fqdn # For example: <<xxxxxxxxxx>>.westeurope.cloudapp.azure.com
$ip = $ilpip1.IpAddress # Please note that is statically assigned, then immediately at creation time
Start-Process "$env:windir\system32\mstsc.exe" -ArgumentList "/v:$ip"
# Once inside the VM, try a second hop with MSTSC to VNName4 and you will succeed, not necessary to create NSG since it is all internal communication #

#endregion SAMPLE[3]: Create a STANDARD internal LB with HA Port feature configured and 1 zoned VM behind it #

#region SAMPLE[4]: Retrieve metrics for STANDARD LB: #
#
# Retrieve metrics and counters (from "AzureRM.Insights" module)
# It will take some time from the resource creation to see output data for the metrics below

# Retrieve all the metrics in extended output format: #
Get-AzureRmMetricDefinition -ResourceId $SLB.Id -DetailedOutput

# Retrieve specific metric definitions: #
Get-AzureRmMetricDefinition -ResourceId $SLB.Id -DetailedOutput -MetricNames "VIPAvailability"
Get-AzureRmMetricDefinition -ResourceId $SLB.Id -DetailedOutput -MetricNames "DIPAvailability"
Get-AzureRmMetricDefinition -ResourceId $SLB.Id -DetailedOutput -MetricNames "ByteCount"
Get-AzureRmMetricDefinition -ResourceId $SLB.Id -DetailedOutput -MetricNames "PacketCount"
Get-AzureRmMetricDefinition -ResourceId $SLB.Id -DetailedOutput -MetricNames "SYNCount"
Get-AzureRmMetricDefinition -ResourceId $SLB.Id -DetailedOutput -MetricNames "SnatConnectionCount"

# Get real metric values: #
(Get-AzureRmMetric -ResourceId $SLB.Id -MetricName "VIPAvailability" -TimeGrain 01:00:00).Data | Format-Table -AutoSize
(Get-AzureRmMetric -ResourceId $SLB.Id -MetricName "DIPAvailability" -TimeGrain 01:00:00).Data | Format-Table -AutoSize
(Get-AzureRmMetric -ResourceId $SLB.Id -MetricName "ByteCount" -TimeGrain 01:00:00).Data | Format-Table -AutoSize
(Get-AzureRmMetric -ResourceId $SLB.Id -MetricName "PacketCount" -TimeGrain 01:00:00).Data | Format-Table -AutoSize
(Get-AzureRmMetric -ResourceId $SLB.Id -MetricName "SYNCount" -TimeGrain 01:00:00).Data | Format-Table -AutoSize
(Get-AzureRmMetric -ResourceId $SLB.Id -MetricName "SnatConnectionCount" -TimeGrain 01:00:00).Data | Format-Table -AutoSize

#endregion SAMPLE[4]: Retrieve metrics for STANDARD LB: #

#region Maintenance & Clean-up #
# 
# List all resources in a ResourceGroup #
Get-AzureRmResource | where-object {$_.ResourceGroupName -eq $rgname} | Select ResourceName,ResourceType

# List all resources in a ResourceGroup of type VIRTUAL MACHINE #
Get-AzureRmResource | where-object {$_.ResourceGroupName -eq $rgname} | where-object {$_.ResourceType -eq "Microsoft.Compute/virtualMachines"} `
 | Select ResourceName,ResourceType

# Stop all the VMs in the ResourceGroup #
Get-AzureRmResource | where-object {$_.ResourceGroupName -eq $rgname} | where-object {$_.ResourceType -eq "Microsoft.Compute/virtualMachines"} `
 | Stop-AzureRmVM -force

# Start all the VMs in the ResourceGroup #
Get-AzureRmResource | where-object {$_.ResourceGroupName -eq $rgname} | where-object {$_.ResourceType -eq "Microsoft.Compute/virtualMachines"} `
 | Start-AzureRmVM

# Delete all the VMs in the ResourceGroup #
Get-AzureRmResource | where-object {$_.ResourceGroupName -eq $rgname} | where-object {$_.ResourceType -eq "Microsoft.Compute/virtualMachines"} `
 | Remove-AzureRmVM -force

# Delete all the Disks in the ResourceGroup #
Get-AzureRmResource | where-object {$_.ResourceGroupName -eq $rgname} | where-object {$_.ResourceType -eq "Microsoft.Compute/disks"} `
 | Remove-AzureRmDisk -force

# Delete all the NICs in the ResourceGroup #
Get-AzureRmResource | where-object {$_.ResourceGroupName -eq $rgname} | where-object {$_.ResourceType -eq "Microsoft.Network/networkInterfaces"} `
 | Remove-AzureRmNetworkInterface -force

# Delete all the Load Balancers in the ResourceGroup #
Get-AzureRmResource | where-object {$_.ResourceGroupName -eq $rgname} | where-object {$_.ResourceType -eq "Microsoft.Network/loadBalancers"} `
 | Remove-AzureRmLoadBalancer -force

# Delete all the Public IPs in the ResourceGroup #
Get-AzureRmResource | where-object {$_.ResourceGroupName -eq $rgname} | where-object {$_.ResourceType -eq "Microsoft.Network/publicIPAddresses"} `
 | Remove-AzureRmPublicIpAddress -force

# Delete all the Virtual Networks in the ResourceGroup #
Get-AzureRmResource | where-object {$_.ResourceGroupName -eq $rgname} | where-object {$_.ResourceType -eq "Microsoft.Network/virtualNetworks"} `
 | Remove-AzureRmVirtualNetwork -force

# Delete all the NSGs in the ResourceGroup #
Get-AzureRmResource | where-object {$_.ResourceGroupName -eq $rgname} | where-object {$_.ResourceType -eq "Microsoft.Network/networkSecurityGroups"} `
 | Remove-AzureRmNetworkSecurityGroup -force

# Delete all the the Storage Accounts in the ResourceGroup #
Get-AzureRmResource | where-object {$_.ResourceGroupName -eq $rgname} | where-object {$_.ResourceType -eq "Microsoft.Storage/storageAccounts"} `
 | Remove-AzureRmStorageAccount -force

# Delete the Resource Group #
Remove-AzureRmResourceGroup $rgname -Force







# Start all the VMs in there 

Get-AzureRmResource | where-object {$_.ResourceGroupName -eq $rgname} | where-object {$_.ResourceType -eq "Microsoft.Compute/virtualMachines"} `
 | Start-AzureRmVM

# Stop all the VMs in there
Get-AzureRmResource | where-object {$_.ResourceGroupName -eq $rgname} | where-object {$_.ResourceType -eq "Microsoft.Compute/virtualMachines"} `
 | Stop-AzureRmVM -Force


 # Cleanup resources, except for VNET, SUBNETs and STORAGE ACCOUNT: #
Remove-AzureRmVM -ResourceGroupName $rgname -Name $VMName -force
Remove-AzureRmNetworkInterface -ResourceGroupName $rgname -Name $NICname -force
Remove-AzureRmPublicIpAddress -ResourceGroupName $rgname -Name $ILPIP1name -force
Remove-AzureRmNetworkSecurityGroup -ResourceGroupName $rgname -Name $NSGname -force
Remove-AzureRmDisk -ResourceGroupName $rgname -Name $OSDiskName -force



#endregion Maintenance & Clean-up #

