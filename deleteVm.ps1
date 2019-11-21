# Arsh Chauhan
# Last Edited: 11/20/2019
# deleteVM.ps1: Delete a VM from subfolders of a given folder
. .\utils.ps1

If ($MyInvocation.line.substring(0,2) -ne ". ") {
    ConnectToVcenter
    $vmName = Read-Host -Prompt "VM to Delete"
    $rootFolder = Read-Host -Prompt "Folder to delete VM's from"
    $subFolders = ListFolderSubfolders($rootFolder)
   
    foreach($folder in $subFolders)
    {
       $vms = Get-VM -Location $folder|Where {($_.Name -like "$vmName*")}
       foreach ($vm in $vms)
         {
             try 
            {
                 Write-Host "Deleting $vm"
                 Remove-VM -Confirm:$false -VM $vm -DeletePermanently
            }
             Catch
            {
            }
        }
    }
}