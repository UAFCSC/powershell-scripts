. .\utils.ps1

If ($MyInvocation.line.substring(0,2) -ne ". ") {
    $labName = Read-Host -Prompt "Lab Name"
    ConnectToVcenter
    DeployLabToMembers $labName
}