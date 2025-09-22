<##########################################################################################################################################
.TITLE          :   DaaS-change-custom-admin-to-full.ps1 

.FUNCTION       :   update Custom admin user to full admin user in Citrix Cloud through REST API

.PARAMETERS     :    
             		mandatory: 
                        adminemail        : email address of the administrator to update 
                        secretPath        : secret API using SPN to logon to cloud. csv file in this format: customerId,citrixAPIKey,secretKey
                        region            : Citrix Cloud region to contact: eu, us or ap are supported, default is set to eu


.EXAMPLE        :
                        .\DaaS-adminupdate-Full.ps1 -adminemail 'vincent.rombau@citrix.com' -secretPath 'C:\SecureClients\Servicee_principalFull.csv' -region 'eu'
   
   

.AUTHOR        :     Vincent Rombau - Solution Architect - Citrix 

.VERSION       : 	 1.0

.HISTORY       :    

#> 



param(
    [Parameter(Mandatory = $false)] [string]$secretPath, # csv file in this format: customerId,citrixAPIKey,secretKey. If this is not present, user will have to logon explicitely
    [Parameter(Mandatory = $false)] [string]$adminemail, # email address of the administrator to update 
    [Parameter(Mandatory = $false)] [string]$region='eu' # eu, us or ap are supported, default is eu
)

#-----------------------------
#   Script prerequisites
#-----------------------------
                $ErrorActionPreference = "Stop"
                $Scriptpath = Split-Path $MyInvocation.MyCommand.Path
                $ScriptName = $MyInvocation.MyCommand.Name
                
                # Create log file
                        $logDir = $Scriptpath+'\Logs'
                        if ((test-path $logDir) -ne "True") {$null = New-Item $Scriptpath\Logs -Type Directory}
                        $logFile  =  Join-Path $logDir ("$($ScriptName)_$(get-date -format yyyy-MM-dd-hh-mm).log")
                       
                # Import Modules
                        try{
                                Import-Module $Scriptpath\Modules\1_cloud_API-General-v2.psm1 -Force
                                Import-Module $Scriptpath\Modules\General.psm1 -Force
                        }
                        catch{
                                Write-host "Error, cannot import Modules or start logging" -ForegroundColor Red 
                        Exit
                        }
                #initialize secretPath
                        if (-NOT $PSBoundParameters.ContainsKey('secretPath')){
                                [string] $secretPath = "$($Scriptpath)\secret.csv"
                        }

        #initialize region
        if (-NOT $PSBoundParameters.ContainsKey('region')){
                $region='eu'
        }
        
#importing secrets: 
        $secret = Import-Csv $secretPath -Delimiter ','
        $customerId = $secret.customerId    
        $clientId = $secret.citrixAPIKey
        $clientSecret = $secret.secretKEY

#Get the Bearer Token
        $token = Get-BearerToken -clientid $clientId -clientsecret $clientSecret -region $region
        #add the log entry to the log file
        add-LogEntry -logEntry $token -logfile $logFile
# Create the header  
        $headers = @{
                Authorization = "CwsAuth Bearer=$($token.data)";
                'Citrix-CustomerId' = $customerId;
                'Accept'="application/json"
                'Content-Type'="application/json"
        }

#fetch administrators
        $myURL = 'https://api.cloud.com/administrators/'
        $result=Invoke-CloudRequest -myURL $myURL -headers $headers
        #add the log entry to the log file
        add-LogEntry -logEntry $result -logfile $logFile
        $administrators = $result.data.items 
        $administrators |out-gridview -Title 'Administrators'

#retrive daministrator userID
        $adminuserID = ($administrators | where-object {($_.email -eq $adminemail) -and ($_.providerType -eq 'CitrixSts')}).userId 

#get administrator Access
        $myURL = "https://api.cloud.com/administrators/$adminuserID/access"
        $result=Invoke-CloudRequest -myURL $myURL -headers $headers
        #add the log entry to the log file
        add-LogEntry -logEntry $result -logfile $logFile
        $AccessType = $result.data.accesstype

#update administrator Access
        if ($AccessType -eq 'Custom'){
            write-host "The administrator $adminemail is on Custom Access, will be updated to Full Access" -ForegroundColor Green
            $myURL = "https://api.cloud.com/administrators/access?id=$adminuserID"
            $body = @{accesstype='Full'} | ConvertTo-Json
            Invoke-RestMethod -Uri $myURL -Method PUT -Headers $headers -Body $body
        }
        else{
            write-host "The administrator $adminemail is already on Full Access, no need to update" -ForegroundColor Yellow
            
        }
