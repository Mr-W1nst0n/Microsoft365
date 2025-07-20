param (
    [System.String]
    $TenantPrefix = "PUTYOURDATAHERE"
)

#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Identity.SignIns

Clear-History
Clear-Host

Try
{
    #Load Environment Variables
    $hostname = $env:computername
    $TenantId = (Get-Item -Path Env:\$($TenantPrefix):TenantId).Value
    $ClientId = (Get-Item -Path Env:\$($TenantPrefix):IntuneAutomationClientId).Value
    $SecretId = (Get-Item -Path Env:\$($TenantPrefix):IntuneAutomationClientSecretValue).Value

    #Logs
    $dateTime = (Get-Date).ToString('dd-MM-yyyy_hh-mm-ss')
    $directoryPath = Split-Path -Parent $PSCommandPath
    $scriptName = [io.path]::GetFileNameWithoutExtension($PSCommandPath)
    $TranscriptOutput = Join-Path -Path $directoryPath -ChildPath "01.Transcript\$TenantPrefix`_$scriptName`_$hostname`_$dateTime.log"

    #Create directories if they don't exist
    $dirs = @(".\01.Transcript", ".\02.Output")
    ForEach ($dir in $dirs)
    {
        If (!(Test-Path $dir))
        {
            New-Item -ItemType Directory -Force -Path "$directoryPath\$dir" | Out-Null
        }
    }

    #Start Transctipt
    Start-Transcript -Path $TranscriptOutput -NoClobber -UseMinimalHeader -IncludeInvocationHeader

    #Convert the Client Secret to a Secure String
    $SecureClientSecret = ConvertTo-SecureString -String $SecretId -AsPlainText -Force

    #Create a PSCredential Object Using the Client ID and Secure Client Secret
    $ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $SecureClientSecret

    #Performance Counter
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    #Connect to Microsoft Graph API
    Connect-MgGraph -NoWelcome -TenantId $TenantId -ClientSecretCredential $ClientSecretCredential

    #Retrieve all conditional access policies from Microsoft Graph API
    $AllPolicies = Get-MgIdentityConditionalAccessPolicy -All

    If ($AllPolicies.Count -eq 0)
    {
        Write-Warning '[!] No CA policies found to export'
    }

    Else
    {
        $folderPath = Join-Path -Path "$directoryPath\02.Output" -ChildPath $dateTime

        If (!(Test-Path $folderPath))
        {
            New-Item -ItemType Directory -Force -Path $folderPath | Out-Null
        }

        ForEach ($Policy in $AllPolicies)
        {
            Try
            {
                #Remove special characters using the -replace operator
                $sanitizedString = $Policy.DisplayName -replace '[\*\?\<\>\|\/\\\:]', ''
          
                #Convert the policy object to JSON with a depth of 6
                $PolicyJSON = $Policy | ConvertTo-Json -Depth 6
           
                #Write the JSON to a file in the export path
                $PolicyJSON | Out-File -FilePath "$folderPath\$sanitizedString.json" -Force
            
                #Print a success message for the policy backup
                Write-Host "Successfully backed up CA policy: $($Policy.DisplayName)" -ForegroundColor Green
            }
            
            Catch
            {
                #Print an error message for the policy backup
                Write-Host "Error occurred while backing up CA policy: $($Policy.DisplayName). $($_.Exception.Message)" -ForegroundColor 'Red'
                $PolicyJSON | Out-File -FilePath "$folderPath\$($Policy.Id).json" -Force
                Write-Host "[LOG] $($Policy.Id) used instead"  -Foregroundcolor 'Red'
            }
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