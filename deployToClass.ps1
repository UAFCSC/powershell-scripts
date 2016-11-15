# Arsh Chauhan
# Last Edited: 11/14/2016
# deployToClass.ps1: Deploy a VM to a class.
#    A class is an arbitary folder in vcenter

. .\utils.ps1

If ($MyInvocation.line.substring(0,2) -ne ". ") {
    $vmName = Read-Host -Prompt "Base VM to Deploy"
    $class = Read-Host -Prompt "Class to deploy to"
    ConnectToVcenter
    $students = ListFolderSubfolders($class)

    $vm = Get-VM "Base $vmName"
    If ($($vm | Get-View).snapshot -eq $null) {
        Write-Host "Cannot clone VM '$vmName' because it has no snapshot(s)."
        exit
    }

    Write-Host "Deploying VM's"
    foreach($student in $students)
    {
        if ([string]$student -ne "Infrastructure") #Do not deploy to infrastructure folder 
        {
            try
            {
                $cloneName = "$vmName - $student"
                DeployVm $student $cloneName $vm
            }
            catch
            {}
        }
    }
    
    #Move all VM's to ESXI2 and consolidate disks
    Write-Host "Moving VM's"
    foreach($student in $students)
    {
        try
        {
            Get-VM -Name "$vmName - $student" | Move-VM -Destination "esxi2.csc.uaf.edu" -Datastore "ESXI2"
            (Get-VM -Name "$vmName - $student").ExtensionData.ConsolidateVMDisks_Task() >$devnull
        }
        catch
        {}
    }
}