#Requirements:
# Active Directory Module for Windows Powershell
# The tool can be downloaded here: http://www.microsoft.com/en-us/download/confirmation.aspx?id=7887
# Installation/configuration guide here: http://blogs.msdn.com/b/rkramesh/archive/2012/01/17/how-to-add-active-directory-module-in-powershell-in-windows-7.aspx
#
# PowerCLI for VMWare VCenter

function ImportPowerCLI() {
    # This imports the PowerCLI functions
    # Write-Host is overwritten in the local scope to prevent the PowerCLI welcome message
    # The error redirection on the import is to hide the Get-PowerCLIVersion error, though
    # the solution can be found here: https://communities.vmware.com/message/2514623 
    function local:Write-Host() {}
    . "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1" 2> $devnull
}

function ConnectToVcenter() {
    ImportPowerCLI

    # Connects to the cventer server using the current account cridentials
    Try {
        $vCenterHostFqdn = "vc.csc.uaf.edu"
        Connect-VIServer -Server $vCenterHostFqdn -Protocol https -WarningAction 0 | Out-Null
        Write-Host "Connected to $vCenterHostFqdn"
    } Catch {
        Read-Host -Prompt "Connection to server failed. Press Enter to exit"
        exit
    }
}

function ListFolderVms($folderName) {
    # This returns the VMs within the folder specified by the string in $folderName
    $folder = Get-Folder $folderName
    $inventory = Get-Inventory -Location $folder -NoRecursion | Where {$_ -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]}
    return $inventory
}

function ListFolderSubfolders($folderName) {
    # This returns the VMs within the folder specified by the string in $folderName
    $folder = Get-Folder $folderName
    $inventory = Get-Inventory -Location $folder -NoRecursion | Where {$_ -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl]}
    return $inventory
}

function GetBaseVms() {
    return ListFolderVMs("Base Templates")
}

function GetBaseLabs() {
    return ListFolderSubfolders("Lab Templates")
}

function MakeMemberFolders() {
    $ErrorActionPreference = "Stop"
    $parentFolder = Get-Folder "CSC Members"
    $folderName = "butts"
    $users = Get-ADUsers something
    foreach ($user in $users) {
        Try {
            $name = $user.displayName
            $memberFolder = New-Folder -Name $folderName -Location $parentFolder
            $memberLabsFolder = New-Folder -Name "Labs" -Location $memberFolder
        } Catch { }
    }
}

function DeployLabToMembers($labName) {
    $memberFolders = ListFolderSubfolders "CSC Members"
    foreach ($memberFolder in $memberFolders) {
        DeployLab $memberFolder $labName #$lab
    }
}

function DeployLab($memberFolder, $labName) {
    $ErrorActionPreference = "Stop"
    # Get the members 'labs' folder
    $memberLabsFolder = Get-Folder -Location $memberFolder -Name "Labs"
    # Get the VMs to copy
    $labVms = ListFolderVms "Base $labName"
    # Copy the lab environment
    Try {
        $memberNewLabFolder = New-Folder -Location $memberLabsFolder -Name $labName
    } Catch [VMware.VimAutomation.ViCore.Types.V1.ErrorHandling.DuplicateName] {
        Write-Host "'$labName' folder already exists in $memberFolder's Labs folder"
        $memberNewLabFolder = Get-Folder $labName -Location $memberLabsFolder
    }
    foreach ($vm in $labVms) {
        If ($($vm | Get-View).snapshot -ne $null) {
            DeployVM $memberNewLabFolder "$vm - $labName - $memberFolder" $vm
        } Else {
            Write-Host "Cannot clone VM '$($vm.name)' because it has no snapshot(s)."
            exit
        }
    }
}

function DeployVmToMembers($vmName) {
    $vm = Get-VM "Base $vmName"
    If ($($vm | Get-View).snapshot -eq $null) {
        Write-Host "Cannot clone VM '$vmName' because it has no snapshot(s)."
        exit
    }
    $memberFolders = ListFolderSubfolders "CSC Members"
    foreach ($memberFolder in $memberFolders) {
        $cloneName = "$vmName - $memberFolder"
        DeployVm $memberFolder $cloneName $vm
    }
}

function DeployVm($location, $cloneName, $vm) {
    $vmView = $vm | Get-View
    #$dest_datastore_name = "ESXI1 CSC DS2 SG500"
    $dest_datastore_name = "ESXImain CSC DS2"
    # Creates a new configuration spec object to be applied to the VM clone
    $cloneSpec = new-object VMware.Vim.VirtualMachineCloneSpec
    $cloneSpec.Snapshot = $vmView.Snapshot.CurrentSnapshot
    $cloneSpec.Location = new-object VMware.Vim.VirtualMachineRelocateSpec
    $cloneSpec.Location.Datastore = (Get-Datastore $dest_datastore_name | Get-View).MoRef
    $cloneSpec.Location.DiskMoveType = [Vmware.Vim.VirtualMachineRelocateDiskMoveOptions]::createNewChildDiskBacking

    $vmView.CloneVM_Task($($location | Get-View).MoRef , $cloneName ,$cloneSpec) > $devnull
    Start-Sleep -s 1
    Write-Host "Cloning to VM: $cloneName"
}