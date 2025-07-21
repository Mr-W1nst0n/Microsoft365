param (
    [Parameter(Mandatory = $false)]
    [System.String]
    $groupName = "PUTYOURVALUEHERE",
    [Parameter(Mandatory = $false)]
    [System.String]
    $TenantPrefix = "PUTYOURVALUEHERE"
)

#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.DeviceManagement
#Requires -Modules Microsoft.Graph.Groups

Clear-History
Clear-Host

Try
{
    #Load Environment Variables
    $hostname = $env:computername
    $TenantId = (Get-Item -Path Env:\$($TenantPrefix):TenantId).Value
    $ClientId = (Get-Item -Path Env:\$($TenantPrefix):IntuneAutomationClientId).Value
    $SecretId = (Get-Item -Path Env:\$($TenantPrefix):IntuneAutomationClientSecretValue).Value

    #Convert the Client Secret to a Secure String
    $SecureClientSecret = ConvertTo-SecureString -String $SecretId -AsPlainText -Force

    #Create a PSCredential Object Using the Client ID and Secure Client Secret
    $ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $SecureClientSecret

    #Logs
    $dateTime = (Get-Date).toString('dd-MM-yyyy_hh-mm-ss')
    $directoryPath = Split-Path -Parent $PSCommandPath
    $scriptName = [io.path]::GetFileNameWithoutExtension($PSCommandPath)
    $TranscriptOutput = Join-Path -Path $directoryPath -ChildPath "01.Transcript\$TenantPrefix`_$scriptName`_$hostname`_$dateTime.log"

    #Start Transctipt
    Start-Transcript -Path $TranscriptOutput -NoClobber -UseMinimalHeader -IncludeInvocationHeader

    #Performance Counter
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    #Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -Certificate $Cert
    Connect-MgGraph -NoWelcome -TenantId $TenantId -ClientSecretCredential $ClientSecretCredential
   
    $Group = Get-MgGroup -Filter "DisplayName eq '$groupName'"
    
    ## -- Device Compliance Policy
    $Resource = "deviceManagement/deviceCompliancePolicies"
    $graphApiVersion = "v1.0"
    #$graphApiVersion = "Beta"
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$expand=Assignments"
    $AllDCPId = (Invoke-MgGraphRequest -Method GET -Uri $uri).Value | Where-Object {$_.assignments.target.groupId -match $Group.id}
    
    Write-Host "Following Device Compliance Policies has been assigned to: $($Group.DisplayName)" -ForegroundColor 'DarkMagenta'
    
    ForEach($DCPId in $AllDCPId)
    {
        Write-Host "$($DCPId.DisplayName)" -ForegroundColor 'Cyan'
    }

    ## -- Applications 
    $Resource = "deviceAppManagement/mobileApps"
    $graphApiVersion = "v1.0"
    #$graphApiVersion = "Beta"
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$expand=Assignments"
    $Apps = (Invoke-MgGraphRequest -Method GET -Uri $uri).Value | Where-Object {$_.assignments.target.groupId -match $Group.id}
    
    Write-Host "Following Apps has been assigned to: $($Group.DisplayName)" -ForegroundColor 'DarkMagenta'
    
    ForEach($App in $Apps)
    {
        Write-Host "$($App.DisplayName)" -ForegroundColor 'Cyan'
    }
    
    ## -- Application Configurations (App Configs)
    $Resource = "deviceAppManagement/targetedManagedAppConfigurations"
    $graphApiVersion = "v1.0"
    #$graphApiVersion = "Beta"
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$expand=Assignments"
    $AppConfigs = (Invoke-MgGraphRequest -Method GET -Uri $uri).Value | Where-Object {$_.assignments.target.groupId -match $Group.id}
    
    Write-Host "Following App Configuration has been assigned to: $($Group.DisplayName)" -ForegroundColor 'DarkMagenta'
    
    ForEach($AppConfig in $AppConfigs)
    {
        Write-Host "$($AppConfig.DisplayName)" -ForegroundColor 'Cyan'
    }
    
    ## -- App protection policies
    $AppProtURIs = @{
        iosManagedAppProtections = "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections?`$expand=Assignments"
        androidManagedAppProtections = "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections?`$expand=Assignments"
        windowsManagedAppProtections = "https://graph.microsoft.com/beta/deviceAppManagement/windowsManagedAppProtections?`$expand=Assignments"
        mdmWindowsInformationProtectionPolicies = "https://graph.microsoft.com/beta/deviceAppManagement/mdmWindowsInformationProtectionPolicies?`$expand=Assignments"
    }

    $graphApiVersion = "v1.0"
    #$graphApiVersion = "Beta"
    
    $AllAppProt = $null
    ForEach($url in $AppProtURIs.GetEnumerator())
    {
        $AllAppProt = (Invoke-MgGraphRequest -Method GET -Uri $url.value).Value | Where-Object {$_.assignments.target.groupId -match $Group.id} -ErrorAction SilentlyContinue
        Write-Host "Following App Protection / "$($url.name)" has been assigned to: $($Group.DisplayName)" -ForegroundColor 'DarkMagenta'
        ForEach($AppProt in $AllAppProt)
        {
            Write-Host "$($AppProt.DisplayName)" -ForegroundColor 'Cyan'
        }
    } 
    
    ## -- Device Configuration
    $DCURIs = @{
        ConfigurationPolicies = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$expand=Assignments"
        DeviceConfigurations = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$expand=Assignments"
        GroupPolicyConfigurations = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations?`$expand=Assignments"
        mobileAppConfigurations = "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppConfigurations?`$expand=Assignments"
    }
    
    $AllDC = $null
    ForEach($url in $DCURIs.GetEnumerator())
    {
        $AllDC = (Invoke-MgGraphRequest -Method GET -Uri $url.value).Value | Where-Object {$_.assignments.target.groupId -match $Group.id} -ErrorAction SilentlyContinue
        Write-Host "Following Device Configuration / "$($url.name)" has been assigned to: $($Group.DisplayName)" -ForegroundColor 'DarkMagenta'
        ForEach($DCs in $AllDC)
        {
            #If statement because ConfigurationPolicies does not contain DisplayName. 
            If($($null -ne $DCs.displayName))
            { 
                Write-Host "$($DCs.DisplayName)" -ForegroundColor 'Cyan'
            } 
            Else
            {
                Write-Host "$($DCs.Name)" -ForegroundColor 'Cyan'
            } 
        }
    } 
    
    ## -- Remediation scripts 
    $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts"
    $REMSC = Invoke-MgGraphRequest -Method GET -Uri $uri
    $AllREMSC = $REMSC.value 
    Write-Host "Following Remediation Script has been assigned to: $($Group.DisplayName)" -ForegroundColor 'DarkMagenta'
    
    ForEach($Script in $AllREMSC)
    {
        $SCRIPTAS = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$($Script.Id)/assignments").value 
        
        If($SCRIPTAS.target.groupId -match $Group.Id)
        {
            Write-Host "$($Script.DisplayName)" -ForegroundColor 'Cyan'
        }
    }

    ## -- Platform Scrips / Device Management
    #$graphApiVersion = "v1.0"
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/deviceManagementScripts"
    $uri = "https://graph.microsoft.com/$graphApiVersion/deviceManagement/deviceManagementScripts"
    $PSSC = Invoke-MgGraphRequest -Method GET -Uri $uri
    $AllPSSC = $PSSC.value
    Write-Host "Following Platform Scripts / Device Management scripts has been assigned to: $($Group.DisplayName)" -ForegroundColor 'DarkMagenta'
    
    Foreach($Script in $AllPSSC)
    {
        $SCRIPTAS = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/$graphApiVersion/deviceManagement/deviceManagementScripts/$($Script.Id)/assignments").value
        
        If($SCRIPTAS.target.groupId -match $Group.Id)
        {
            Write-Host "$($Script.DisplayName)" -ForegroundColor Yellow
        }
    }

    ## -- Windows AutoPilot profiles
    $Resource = "deviceManagement/windowsAutopilotDeploymentProfiles"
    #$graphApiVersion = "v1.0"
    $graphApiVersion = "Beta"
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?`$expand=Assignments"
    $Response = Invoke-MgGraphRequest -Method GET -Uri $uri
    $AllObjects = $Response.value
    Write-Host "Following Autopilot Profiles has been assigned to: $($Group.DisplayName)" -ForegroundColor 'DarkMagenta'
    
    Foreach($AutoPilotProfile in $AllObjects)
    {
        $APProfile = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/$graphApiVersion/deviceManagement/windowsAutopilotDeploymentProfiles/$($AutoPilotProfile.Id)/assignments").value 
        
        If($APProfile.target.groupId -match $Group.Id)
        {
            Write-Host "$($AutoPilotProfile.DisplayName)" -ForegroundColor 'Cyan'
        }
    }
    
    Disconnect-Graph | Out-Null
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