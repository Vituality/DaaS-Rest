<#  
##########################################################################################################################################
.TITLE          :   Cloud-REST

.FUNCTION       :   Querry Citrix Cloud through REST

.PARAMETERS     :    
             		mandatory: 
                        client_id         : ID for Citrix cloud API access - see "Get started with Citrix cloud API" https://developer.cloud.com/explore-more-apis-and-sdk/cloud-services-platform/citrix-cloud-api-overview/docs/get-started-with-citrix-cloud-apis
                        client_secret     : Client Secret for Citrix cloud API access - see "Get started with Citrix cloud API" https://developer.cloud.com/explore-more-apis-and-sdk/cloud-services-platform/citrix-cloud-api-overview/docs/get-started-with-citrix-cloud-apis
                        customer_id       : Customer ID for Citrix cloud API access - see "Get started with Citrix cloud API" https://developer.cloud.com/explore-more-apis-and-sdk/cloud-services-platform/citrix-cloud-api-overview/docs/get-started-with-citrix-cloud-apis


.REQUIEREMENTS  :     
                    Access to Citrix Cloud over the Internet
                    #Read the parameters passed from command line
                    # secret.csv file syntax
                    # customerId,citrixAPIKey,secretKey
                    #########,######-#####-####-####-############,######################

.EXAMPLE        :
                    
   
   

.AUTHOR        :     Vincent Rombau - Solution Architect - Citrix 

.VERSION       : 	 0.

.HISTORY       :    

#> 



param(
    [Parameter(Mandatory = $false)] [string]$secretPath, # csv file in this format: customerId,citrixAPIKey,secretKey. If this is not present, user will have to logon explicitely
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
        }

#Amount of users in DaaS
                      switch ($region)
                {
                'us' {$myurl = "https://api-us.cloud.com/monitorodata/sessions"}
                'eu' {$myurl = "https://api-eu.cloud.com/monitorodata/sessions"}
                'ap' {$myurl = "https://api-ap-s.cloud.com/monitorodata/sessions"}
                }
        $Parameters = @{             
                '$apply' = "filter((CreatedDate gt 2024-01-16) and (Currentconnection/ClientVersion ne null) and (Currentconnection/ClientVersion ne ''))/groupby((user/Upn))";
                '$count' = "true"
              }
      
        $result=Invoke-odata -myURL $myURL -headers $headers -parameters $parameters
        #add the log entry to the log file
        add-LogEntry -logEntry $result -logfile $logFile
        ($result.data.value) |out-gridview -Title 'Amount of users'
        Write-host "Total amount of users: $($result.data.value.count)" -ForegroundColor Green

#Amount of machines in DaaS
                      switch ($region)
                {
                'us' {$myurl = "https://api-us.cloud.com/monitorodata/sessions"}
                'eu' {$myurl = "https://api-eu.cloud.com/monitorodata/sessions"}
                'ap' {$myurl = "https://api-ap-s.cloud.com/monitorodata/sessions"}
                }
        $Parameters = @{             
                '$apply' = "filter((CreatedDate gt 2024-01-16) and (Currentconnection/ClientVersion ne null) and (Currentconnection/ClientVersion ne ''))/groupby((CurrentConnection/ClientName))";
                '$count' = "true"
              }
      
        $result=Invoke-odata -myURL $myURL -headers $headers -parameters $parameters
        #add the log entry to the log file
        add-LogEntry -logEntry $result -logfile $logFile
        ($result.data.value) |out-gridview -Title 'Amount oif machines'
        Write-host "Total amount of machines: $($result.data.value.count)" -ForegroundColor Green