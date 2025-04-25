if ($notifications) {Clear-Variable -Name notifications}
if ($systemlogs) {Clear-Variable -Name systemlogs}

#Initializing customerID
        $customerId = 'dcint4b1816a'    
#importing secureAPI : 
        $secret = Import-Csv 'C:\SecureClients\secret\serviceprincipal-Full.csv' -Delimiter ','
        #$secret = Import-Csv 'C:\SecureClients\secret\SecureAPI-Full.csv' -Delimiter ','
        $clientId = $secret.ID
        $clientSecret = $secret.Secret

#Get the Bearer Token
        $tokenUrl = "https://api-us.cloud.com/cctrustoauth2/root/tokens/clients"
        $response = Invoke-WebRequest $tokenUrl -Method POST -Body @{
                grant_type    = "client_credentials"
                client_id	  = $clientId
                client_secret = $clientSecret
                }
        $token = ($response.Content | ConvertFrom-Json).access_token
        
# Create the header  
        $headers = @{
                Authorization = "CwsAuth Bearer=$($token)";
                'Citrix-CustomerId' = $customerId;
                'Accept'="application/json"
        }

#notifications
        $myurl = "https://api.cloud.com/notifications"
        $notifications=((Invoke-WebRequest $myURL -Headers $headers)|convertfrom-json).items
        if ($notifications) {
                write-host -ForegroundColor Green "Notifications found"
        }
        else{
                write-host -ForegroundColor Red "Notifications not found"
        }

#system logs
        $myurl = "https://api.cloud.com/systemlog/records"
        $systemlogs=((Invoke-WebRequest $myURL -Headers $headers)|convertfrom-json).items
        
        if ($systemlogs) {
                write-host -ForegroundColor Green "System logs found"
        }
        else{
                write-host -ForegroundColor Red "System logs not found"
        }