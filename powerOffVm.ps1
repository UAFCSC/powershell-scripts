# Arsh Chauhan
# Last Edited: 11/12/2016
# powerOffVm.ps1: Power Off all VM's that conatain the given name in the given folder

. .\utils.ps1

If ($MyInvocation.line.substring(0,2) -ne ". ") {
    ConnectToVcenter
    $vmName = Read-Host -Prompt "VM to power off"
    $rootFolder = Read-Host -Prompt "Folder to power off VM's"
    $subFolders = ListFolderSubfolders($rootFolder)
   
    foreach($folder in $subFolders)
    {
       $vms = Get-VM -Location $folder|Where {($_.Name -like "$vmName*")}
       foreach ($vm in $vms)
         {
             try 
            {
                 Write-Host "Powering Off $vm"
                 Stop-VM -Confirm:$false -VM $vm
            }
             Catch
            {
            }
        }
    }
}