. .\utils.ps1

If ($MyInvocation.line.substring(0,2) -ne ". ") {
    $vmName = Read-Host -Prompt "VM Name"
    ConnectToVcenter
    DeployVmToMembers $vmName
}