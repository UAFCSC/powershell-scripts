# Arsh Chauhan
# Last Edited: 11/12/2016
# powerOffLab.ps1: Power Off all VM's in a lab folder for all members
. .\utils.ps1

If ($MyInvocation.line.substring(0,2) -ne ". ") 
{
    ConnectToVcenter
    $labName = Read-Host -Prompt "Name of Lab to Poweroff"
    $labs=ListFolderSubfolders("Labs")
    $vms

    Write-Host "Collecting Labs and VM's"
    foreach($lab in $labs)
    {
        if([system.string]$lab -eq $labName)
           {
                $vms = ListFolderVms($lab)
           }
    }
    
    Write-Host "Initiating VM Power off"
    foreach($vm in $vms)
    {
         
         try 
            {
                 Stop-VM -Confirm:$false -VM $vm
                 Write-Host "Powering Off $vm"
            }
         Catch
            {
            }
    }
}