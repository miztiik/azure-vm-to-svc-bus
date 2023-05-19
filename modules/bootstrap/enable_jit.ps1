## Build the policy with the VM's resource ID

Select-AzSubscription -Tenant 'dd75bfd4-42ba-476a-a2d2-60fd44086ac1'

Import-Module Az.Security

$vmLocation="northeurope"
$vmName = "m-web-srv-002"
$resourceGroupName = "Miztiik_Enterprises_vm_to_svc_bus_002"
$subscriptionId = "58379947-56e0-477a-bbe3-8e671aadab83"



$JitPolicy = (@{ id="/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/$vmName"
ports=(@{
     number=22; ## SSH
     protocol="*"; ## all protocols
     allowedSourceAddressPrefix=@("*"); ## any source IP
     maxRequestAccessDuration="PT3H"}, ## up to three hours
     @{
     number=3389;
     protocol="*";
     allowedSourceAddressPrefix=@("*");
     maxRequestAccessDuration="PT3H"})})
$JitPolicyArr=@($JitPolicy)

## Send the policy to Azure and commit it to the VM
Set-AzJitNetworkAccessPolicy -Kind "Basic" -Location $vmLocation -Name $vmName -ResourceGroupName $resourceGroupName -VirtualMachine $JitPolicyArr

Auditing JIT Access Activity