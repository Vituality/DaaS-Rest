<#  
##########################################################################################################################################
.TITLE          :   DaaS-change-custom-admin-to-full.ps1

.FUNCTION       :   update Custom admin user to full admin user in Citrix Cloud through REST API

.PARAMETERS     :    
             		mandatory: 
                        adminemail        : email address of the administrator to update 
                        secretPath        : secret API using SPN to logon to cloud. csv file in this format: customerId,citrixAPIKey,secretKey
                        region            : Citrix Cloud region to contact: eu, us or ap are supported, default is set to eu


.EXAMPLE        :
                        .\DaaS-change-custom-admin-to-full.ps1 -adminemail 'vincent.rombau@citrix.com' -secretPath 'C:\SecureClients\Servicee_principalFull.csv' -region 'eu'
   
   

.AUTHOR        :     Vincent Rombau - Solution Architect - Citrix 

.VERSION       : 	 1.0

.HISTORY       :    

#> 



param(
    [Parameter(Mandatory = $false)] [string]$secretPath, # csv file in this format: customerId,citrixAPIKey,secretKey. If this is not present, user will have to logon explicitely
    [Parameter(Mandatory = $false)] [string]$adminemail, # email address of the administrator to update 
    [Parameter(Mandatory = $false)] [string]$region='eu' # eu, us or ap are supported, default is set to eu
)


add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'                


#-----------------------------
#   Script prerequisites
#-----------------------------
        $ErrorActionPreference = "Stop"
        $Scriptpath = Split-Path $MyInvocation.MyCommand.Path
        #initialize secretPath
                if (-NOT $PSBoundParameters.ContainsKey('secretPath')){
                        [string] $secretPath = "$($Scriptpath)\secret.csv"
                }

    #initialize region
        if (-NOT $PSBoundParameters.ContainsKey('region')){
                $region='eu'
        }
        switch ($region){
            'us' {$tokenUrl = "https://api-us.cloud.com/cctrustoauth2/root/tokens/clients"}
            'eu' {$tokenUrl = "https://api-eu.cloud.com/cctrustoauth2/root/tokens/clients"}
            'ap' {$tokenUrl = "https://api-ap-s.cloud.com/cctrustoauth2/root/tokens/clients"}
        }
        
    #importing secrets: 
        $secret = Import-Csv $secretPath -Delimiter ','
        $customerId = $secret.customerId    
        $clientId = $secret.citrixAPIKey
        $clientSecret = $secret.secretKEY

# get the bearer token
        try{

                $response = Invoke-WebRequest $tokenUrl -Method POST -Body @{
                    grant_type    = "client_credentials"
                    client_id	  = $clientId
                    client_secret = $clientSecret
                }
                $token = ($response.Content | ConvertFrom-Json).access_token
                write-host "bearer token retrieved" -ForegroundColor Green
        } 
        catch{
                write-host "Error retrieving bearer token" -ForegroundColor Red
        }
# Create the header  
        $headers = @{
                Authorization = "CwsAuth Bearer=$($token)";
                'Citrix-CustomerId' = $customerId;
                'Accept'="application/json"
                'Content-Type'="application/json"
        }

#fetch administrators
        $myURL = 'https://api.cloud.com/administrators/'
        $result=Invoke-WebRequest $myURL -Headers $headers
        $administrators =  ($result.Content|convertfrom-json).items

#retrive daministrator userID
        $adminuserID = ($administrators | where-object {($_.email -eq $adminemail) -and ($_.providerType -eq 'CitrixSts')}).userId 

#get administrator Access
        $myURL = "https://api.cloud.com/administrators/$adminuserID/access"
        $result=Invoke-RestMethod -Uri $myURL -Method GET -Headers $headers
        $AccessType = $result.accesstype

#update administrator Access
        if ($AccessType -eq 'Custom'){
            write-host "The administrator $adminemail is on Custom Access, will be updated to Full Access" -ForegroundColor Green
            $myURL = "https://api.cloud.com/administrators/access?id=$adminuserID"
            $body = @{accesstype='Full'} | ConvertTo-Json
            Invoke-RestMethod -Uri $myURL -Method PUT -Headers $headers -Body $body
            write-host "The administrator $adminemail has been updated to Full Access" -ForegroundColor Green
        }
        else{
            write-host "The administrator $adminemail is already on Full Access, no need to update" -ForegroundColor Yellow
            
        }


