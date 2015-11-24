#
# deployByList.ps1
# This script will present the user with a GUI, asking for input on which machine or machines
# to deploy. 
#

Function DeployVMList ($base_vm_hash) {
    echo "VMs to be deployed:"
    $vm_list = $base_vm_hash.Get_Item("vm_list")
    foreach ($vm_name in $vm_list) {
        echo "  $vm_name"
        DeployBaseClone $vm_name $base_vm_hash.Get_Item("host") $base_vm_hash.Get_Item("datastore")
        # Give a little time for those VM to deploy (except on the last itteration)
        if ($vm_name -ne $vm_list[-1]) {
            Start-Sleep -s 10
        }
    }
}

Function DeployBaseClone ($raw_vm_name, $dest_host_name, $dest_datastore_name) {
    # Generates the name of the source VM to clone
    $src_vm_name = "Base " + $raw_vm_name

    # Gets the VM object of the VM that will be cloned
    $src_vm = (Get-VM $src_vm_name | Get-View) 2>$devnull
    if (!$src_vm) {
        echo "    No VM with name: $src_vm_name"
        return
    }
    
    # Creates a new configuration spec object to be applied to the VM clone
    $clone_spec = new-object VMware.Vim.VirtualMachineCloneSpec
    $clone_spec.Snapshot = $src_vm.Snapshot.CurrentSnapshot
    $clone_spec.Location = new-object VMware.Vim.VirtualMachineRelocateSpec
    $clone_spec.Location.Datastore = (Get-Datastore $dest_datastore_name | Get-View).MoRef
    $clone_spec.Location.DiskMoveType = [Vmware.Vim.VirtualMachineRelocateDiskMoveOptions]::createNewChildDiskBacking
    
    # Begin deploying clones to each users folder
    $user_folders = Get-Folder -L 'CSC Members' -NoRecursion
    
    
    foreach ($user_name in $user_folders){
        # Generates the name for the new VM (appending the users name to the VM name)
        $full_vm_name = "$raw_vm_name $user_name"
        
        # Gets the object for the target folder the VM will be cloned to
        $dest_folder = (Get-Folder -Name $user_name | Get-View).MoRef
        
        # Begins the cloning task
        # NOTE: If you are trying to debug deployment failure, comment out the '>$devnull' bit
        #       That output redirect is to keep the script output clean
        $src_vm.CloneVM_Task($dest_folder, $full_vm_name, $clone_spec) >$devnull
        echo "    Cloning VM: $full_vm_name"
        Start-Sleep -s 5
    }
}

# This makes the powershell instance a VMware powershell instance (needed to use VMware objects)
. "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1" 2>$devnull

# Connects to the cventer server using the current account cridentials
Try   {  Connect-VIServer -Server vc.csc.uaf.edu -Protocol https -WarningAction 0 }
Catch {  Read-Host -Prompt "Press Enter to exit" }
echo "`n`n"

# Set variables for the deployment
$universal_datastore = "ESXI1 CSC DS2 SG500"

$selected_host = "esximain.csc.uaf.edu"

# VM Lists
$base_vms_linux = @{
    "vm_list" = @('CentOS 6.5',
                'CentOS 6.5 (no EPEL)',
                'Fedora Core 11',
                'Fedora Core 16',
                #'Kali Linux',
                'Linux Mint',
                'Metasploitable 2',
                'Ubuntu 12.04',
                'Ubuntu 15.04',
                'Debian 8.2',
                'Ubuntu 10.04 GUI');
    "datastore" = $universal_datastore;
    "host" = $selected_host;
    }
$base_vms_windows = @{
    "vm_list" = @('Win 2003 R2',
                'Win 2008 R2',
                'Win 2008 Std SP1',
                'Win 2008 Std SP1 x2',
                'Win 2012 R2',
                'Win 7',
                'Win 8.1',
                'Win 10','Windows Lab 01','Win Firewall Lab 1');
    "datastore" = $universal_datastore;
    "host" = $selected_host;
    }
$base_vms_other = @{
    "vm_list" = @('Solaris 10',
                'FreeBSD 8.4',
                'FreeBSD 9.1');
    "datastore" = $universal_datastore;
    "host" = $selected_host;
    }

# Builds a GUI input box
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null
$input_content = "Enter a list option ('All','Linux','Windows','Other') or specific VM name (eg: FreeBSD 9.1)"
$input_title = "Select List"
$input_textfield = ""
$selected_list_option = [Microsoft.VisualBasic.Interaction]::InputBox($input_content, $input_title, $input_textfield)
$base_vms_hash = @{}

# Basic input validation. Builds the list of VMs to be deployed based on the user input
switch ($selected_list_option.ToLower()) {
    "linux"     { $base_vms_hash = $base_vms_linux }
    "windows"   { $base_vms_hash = $base_vms_windows }
    "other"     { $base_vms_hash = $base_vms_other }
    "all"       { $base_vms_hash = $base_vms_linux + $base_vms_windows + $base_vms_other }
    ""          { echo "Must provide VM name or VM name list"; Exit }
    default     {
                    echo $selected_list_option
                    $base_vms_hash = @{"vm_list" = $selected_list_option}
                    if ($base_vms_linux.Get_Item("vm_list") -contains $selected_list_option) {
                        $base_vms_hash.Add("datastore", $base_vms_linux.Get_Item("datastore"))
                    }
                    elseif ($base_vms_windows.Get_Item("vm_list") -contains $selected_list_option) {
                        $base_vms_hash.Add("datastore", $base_vms_windows.Get_Item("datastore"))
                    }
                    elseif ($base_vms_other.Get_Item("vm_list") -contains $selected_list_option) {
                        $base_vms_hash.Add("datastore", $base_vms_other.Get_Item("datastore"))
                    }
                    else {
                        Read-Host -Prompt "Couldn't find virtual machine with that name. Press Enter to exit"
                        return
                    }
                }
}

# Deploys the VM list
DeployVMList $base_vms_hash

# Catches the shell from closing- useful if there's errors during the deployment process
Read-Host -Prompt "Press Enter to exit"