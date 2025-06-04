param (
    [Parameter(Mandatory = $false)]
    [System.String]
    $ListUsers = "C:\CODE\AWS\Users.csv"
)

#Requires -Version 7.0
#Requires -Modules AWSPowerShell.NetCore

Clear-History
Clear-Host

Try
{
    #Load Environment Variables
    $hostname = $env:computername
    $AWSLocalProfileConfigName = 'my-sso-profile'
    $AWSWorkSpacesIAM = 'PUTYOURDATAHERE'
    $AWSWorkSpacesRegion = 'eu-central-1'
    $AWSWorkSpacesCustomBundle = 'PUTYOURDATAHERE' #Windows11_V23H2_Image_WSP
    $AWSWorkSpacesDefaultKMSKey = 'PUTYOURDATAHERE'
    $AWSWorkSpacesRunningMode = 'AUTO_STOP'
    $AWSWorkSpacesRunningModeTimeOut = '60'
    $AWSWorkSpacesTagRequest = 'PUTYOURDATAHERE' #Optional
    $AWSWorkSpacesTagService = 'PUTYOURDATAHERE' #Optional

    #Logs
    $dateTime = (Get-Date).toString('dd-MM-yyyy_hh-mm-ss')
    $directoryPath = Split-Path -Parent $PSCommandPath
    $scriptName = [io.path]::GetFileNameWithoutExtension($PSCommandPath)
    $TranscriptOutput = Join-Path -Path $directoryPath -ChildPath "01.Transcript\$scriptName`_$hostname`_$dateTime.log"
    $LogOutput = Join-Path -Path $directoryPath -ChildPath "02.Logs\AWSWorkSpaceslog.csv"

    If (!(Test-Path "$directoryPath\01.Transcript"))
    {
        $null = New-Item -ItemType Directory -Force -Path "$directoryPath\01.Transcript"
    }

    If (!(Test-Path "$directoryPath\02.Logs"))
    {
        $null = New-Item -ItemType Directory -Force -Path "$directoryPath\02.Logs"
    }

    $CSVUsers = Import-Csv $ListUsers -Encoding utf8 -Delimiter ';'

    #Start Transctipt
    Start-Transcript -Path $TranscriptOutput -NoClobber -UseMinimalHeader -IncludeInvocationHeader

    #Performance Counter
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    #AWS Stuff
    Set-AWSCredential -ProfileName $AWSLocalProfileConfigName
    Invoke-AWSSSOLogin -ProfileName $AWSLocalProfileConfigName

    [Amazon.WorkSpaces.Model.WorkspaceProperties] $WorkspaceProperties = New-object -TypeName Amazon.WorkSpaces.Model.WorkspaceProperties
    $WorkspaceProperties.RunningMode = [Amazon.Workspaces.RunningMode]::$AWSWorkSpacesRunningMode
    $WorkspaceProperties.RunningModeAutoStopTimeoutInMinutes = $AWSWorkSpacesRunningModeTimeOut

    ForEach ($User in $CSVUsers.UserName)
    {
        #Create the actual workspaces
        Try
        {
            $result = New-WKSWorkspace -Workspace @{
                        "BundleId" = $AWSWorkSpacesCustomBundle;
                        "DirectoryId" = $AWSWorkSpacesIAM;
                        "UserName" = $User;
                        "WorkspaceProperties" = $WorkspaceProperties;
                        "VolumeEncryptionKey" = $AWSWorkSpacesDefaultKMSKey;
                        "RootVolumeEncryptionEnabled" = $true;
                        "UserVolumeEncryptionEnabled" = $true;
                        "Tags" = @(
                            @{ "Key" = "request"; "Value" = $AWSWorkSpacesTagRequest },
                            @{ "Key" = "service"; "Value" = $AWSWorkSpacesTagService }
                        )
                    } -Region $AWSWorkSpacesRegion
        }

        Catch
        {
            $ErrorMessage = $_.Exception.Message
            Write-host $ErrorMessage
            $FailedItem = $_.Exception.ItemName
            Write-host $FailedItem
            Break
        }

        $Date = (get-date).ToString("MM-dd-yyyy")
        If ($result.PendingRequests.State -eq 'PENDING')
        {
            #If the workspace creation is successful output and log user and WorkSpace ID
            "Resource creation for $User is pending with ID:  " + $result.PendingRequests.WorkSpaceId
            $Status = "Resource creation is pending"
            $Status | Select-Object @{Name = "Date"; Expression = { $Date } }, @{Name = "Status"; Expression = { $Status } }, @{Name = "User"; Expression = { $User } }, @{Name = "WorkSpaceId"; Expression = { $result.PendingRequests.WorkSpaceId } } | Export-csv $LogOutput -notypeinformation -Append
        }

        If ($null -ne $result.FailedRequests.ErrorCode)
        {
            #If the workspace creation is failed output and log user and reason
            "Resource creation for $User failed with message:  " + $result.FailedRequests.ErrorMessage
            $Status = "Resource creation failed"
            $Status | Select-Object @{Name = "Date"; Expression = { $Date } }, @{Name = "Status"; Expression = { $result.FailedRequests.ErrorMessage } }, @{Name = "User"; Expression = { $User } }, @{Name = "WorkSpaceId"; Expression = { $result.PendingRequests.WorkSpaceId } } | Export-Csv $LogOutput -notypeinformation -Append
        }
    }
}

Catch
{
    Write-Host "[ERR] Encountered Error: " $_ -ForegroundColor 'Red'
}

Finally
{
    #Performance Counter
    $stopwatch.Stop()
    $executionTime = $stopwatch.Elapsed
    Write-Host "[END] Script Execution Time: $executionTime" -ForegroundColor 'DarkGreen'

    #Stop Transcript
    Stop-Transcript
}
