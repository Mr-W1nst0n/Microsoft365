#Requires -Version 7.0
#Requires -Modules AWSPowerShell.NetCore

Clear-History
Clear-Host

$params = @{
  ProfileName = 'my-sso-profile'
  AccountId = 'PUTYOURVALUEHERE' #modify with your AccountId
  RoleName = 'PowerUserAccess'
  SessionName = 'my-sso-session'
  StartUrl = 'https://PUTYOURVALUEHERE.awsapps.com/start' #modify with your TenantPrefix
  SSORegion = 'eu-central-1'
  RegistrationScopes = 'sso:account:access'
};

Initialize-AWSSSOConfiguration @params

#To Validate
Get-AWSCredentials -ListProfileDetail