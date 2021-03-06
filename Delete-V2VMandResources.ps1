﻿  <#
  .SYNOPSIS
  Ever feel it’s a pain to clear resources of a test virtual machine azure, worry no more.
  
  .DESCRIPTION
  This script deletes resources unique to a virtual machine. The script will delete a machine and all its resource i.e. Public IP, Network Interface, Virtual Machine and Disks. It will not delete any resource that can be a shared resource e.g. Virtual Network, Network Security Groups, or storage account.
  
  .EXAMPLE
  Delete-V2VMandResources.ps1 -SubscriptionId "1d6737e7-4f6c-4e3c-8cd4-996b6f003d0e" -rgName DVideoRG1 -VMNames DV1-DPBSV1-002 -DeleteDisks

  This will delete virtual machine and all resources including OS and data disks attached to virtual machine 
      
  .EXAMPLE
  Delete-V2VMandResources.ps1 -SubscriptionId "1d6737e7-4f6c-4e3c-8cd4-996b6f003d0e" -rgName DVideoRG1 -VMNames DV1-DPBSV1-002

  This will delete virtual machine and all resources excluding OS and data disks attached to virtual machine
    
  .EXAMPLE
  Delete-V2VMandResources.ps1 -SubscriptionId "1d6737e7-4f6c-4e3c-8cd4-996b6f003d0e" -rgName DVideoRG1 -VMNames "DV1-DPBSV1-001","DV1-DPBSV1-002"

  This will delete both virtual machines and all resources excluding their OS and data disks attached to virtual machines
      
  .PARAMETER SubscriptionId
  Subscription ID for the subscription that virtual machine is on
    
  .PARAMETER rgName
  The Resource Group the virtual machine belongs to. Required

  .PARAMETER VMNames
  The name or names of the virtual machine(s) to be deleted. Required
  
  .SWITCH DeleteDisks
  When switch is present, script will delete disk attached to virtual machine. DELETING OF DISK MEANS THERE IS A POTENTIAL FOR DATA LOSS, USE AT YOUR OWN RISK.

  .SWITCH NoAuth
  When switch is present, script will skip prompting for Azure credential. Use this option only if you have already authenticated to Azure on this Powershell session.

  .NOTES
  File Name  : Delete-V2VMandResources.ps1
  Author     : Hannel Hazeley - hhazeley@outlook.com
  Version    : 2.0
  Requires   : Azure PowerShell 3.0 and higher

  .LINK
  https://???????//

  #>

[cmdletbinding()]
Param (
    [Parameter(Mandatory=$true)]
    $SubscriptionId,
    [Parameter(Mandatory=$true)]
    $rgName,
    [Parameter(Mandatory=$true)]
    $VMNames, 
    [Switch]$DeleteDisks,
    [Switch]$NoAuth
)

if ($NoAuth.IsPresent)
{
Write-Host ""
Write-Host -ForegroundColor Yellow "Skipping Login in to Azure"
Write-Host ""
}
Else
{
#Login into Azure
Login-AzureRmAccount | Out-Null
}

#Selecting subscription
Select-AzureRmSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop

foreach ($vmname in $vmnames)
{
#stop VM 
Stop-AzureRmVM -Name $vmname -ResourceGroupName $rgName -Force | Out-Null

#Get details of VM
$vm = get-azurermvm -ResourceGroupName $rgName -Name $vmname

#Deleted VM 
Remove-AzureRmVM -ResourceGroupName $rgName -Name $vmname -Force -Verbose

#Use VM details to identify and delete network resources, NIC and PIP
$nics = $vm.NetworkInterfaceIDs
$nics | % {
$niname = $_ -replace '.*?interfaces/',""
$nic = Get-AzureRmNetworkInterface -Name "$niname" -ResourceGroupName $rgName 
$pupipname = $nic.IpConfigurations.Publicipaddress.Id -replace '.*?addresses/',""
Remove-AzureRmNetworkInterface -Name "$niname" -ResourceGroupName $rgName -Force
if ($pupipname -ne $null)
{
Remove-AzureRmPublicIpAddress -Name "$pupipname" -ResourceGroupName $rgName -Force
}
}

if ($DeleteDisks.IsPresent)
{
#3 minutes script sleep to release disks 
Start-Sleep -Seconds 180

#Use VM details to identify and delete data disk 
$DataDisks = $vm.StorageProfile.DataDisks
$DataDisks | % {
$vhduri = $_.Vhd.Uri
$SA = Get-AzureRmStorageAccount -ResourceGroupName $rgName -name ($VHDuri).Split('/')[2].Split('.')[0] 
$SA | Remove-AzureStorageBlob -Blob ($VHDuri).Split('/')[-1] -Container ($VHDuri).Split('/')[-2] -Force -Verbose
}

#Use VM details to identify and delete data disk 
$osDisk = $vm.StorageProfile.OsDisk
$vhduri = $Osdisk.Vhd.Uri
$SA = Get-AzureRmStorageAccount -ResourceGroupName $rgName -name ($VHDuri).Split('/')[2].Split('.')[0] 
$SA | Remove-AzureStorageBlob -Blob ($VHDuri).Split('/')[-1] -Container ($VHDuri).Split('/')[-2] -Force -Verbose
}
Write-Host ""
Write-Host -ForegroundColor Green "Clean-up for $vmname completed."
Write-Host ""
}