# AzureStandardLoadBalancer
Samples for my blog post on new Azure Standard SKU Load Balancer

Since the Standard SKU Load Balancer is new, and some behaviors are different from the past, I created some very simple samples using PowerShell you can play with and customize. You can find at this link on GitHub. Please be aware that these are NOT production ready, I created them only for learning purpose. Additionally, the code in the samples is not intended to be launched all in once. Instead, you should carefully review each commented section, understand the effects, then run it to observe the outcome. 

SAMPLE[1]: Create a simple zoned VM with an instance level Standard IP (ILPIP). Look how to create a VM in a specific Azure Availability Zone (AZ), then create a new Standard SKU type Public IP and use it to expose the VM. A Network Security Group (NSG) is necessary to permit traffic through the Standard Public IP, differently from Basic Public IP as done in the past, where all the ports were open for VM access.

SAMPLE[2]: Create a new type Standard SKU Load Balancer (LB), and use it in conjunction with a new Standard SKU type Public IP. Then, create two "zoned" VMs with Managed Disks, each one hosted in a different Azure Availability Zone (AZ). Worth noting that the two VMs will be in the same subnet and Virtual Network, even if in different AZs. Finally, will be demonstrated how Standard Load Balancer will transparently redirect to the VM in Zone[2] if VM in Zone[1] will be down. In this sample, the necessary NSG will be created and bound to the subnet level, not at the specific VM NIC as in the previous example. 

SAMPLE[3]: Create a Standard SKU internal Load Balancer (ILB) with HA Port configured and 1 zoned VM behind it. You will see how the publishing rule for this feature is different, and how it works with VM created in a specific Zone. 

SAMPLE[4]: You will see here how to retrieve metric definitions and values for Standard SKU Load Balancer (LB), using PowerShell.

