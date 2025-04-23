
Param(
    
    [string]$client_id='0e3b9a89-8fe3-43e2-acdf-49d27c556627',
    
	[string]$client_secret='O96pDtu4SfxqbTgi7rdrIw==',
    
	[string]$customer_id='dcint4b1816a'

)

	$ErrorActionPreference = "Stop"

    <#
    The web server we are connecting to may not have a trusted security certificate on the host running the PowerShell script. We need to change the certificate policy to prevent errors. 
    REST API requires TLS 1.2, which isn�t enabled by default in PowerShell 5 and below. 
    #>

    [string]$client_id='0e3b9a89-8fe3-43e2-acdf-49d27c556627'
    
	[string]$client_secret='O96pDtu4SfxqbTgi7rdrIw=='
    
	[string]$customer_id='dcint4b1816a'

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

# get the bearer token
try 
	{
        $tokenUrl = 'https://api-us.cloud.com/cctrustoauth2/root/tokens/clients'
        $response = Invoke-WebRequest $tokenUrl -Method POST -Body @{
	        grant_type    = "client_credentials"
	        client_id	  = $client_id
	        client_secret = $client_secret
        }
        $token = ($response.Content | ConvertFrom-Json).access_token
    } 
	catch 
	{
		return "An error occurred."
	}

# Create the headers  
    $headers = @{
	    Authorization = "CwsAuth Bearer=$($token)"
        Accept = "application/json"
	    'Citrix-CustomerId' = $customer_id;
    }
    
# define URL    
    $myurl = "https://api.cloud.com/connectors"
    
    write-host "Retrieving Data ."
    $CloudConnectors = ((Invoke-WebRequest $myurl -Headers $headers)  | ConvertFrom-Json )
    $length = $CloudConnectors.count

    write-host 'Discovered' $length 'different cloud connetcors'

    foreach ($cloudconnector in $cloudconnectors){
        write-host "Cloud connector FQDN $($cloudconnector.fqdn) lastcontactdate $($cloudconnector.lastcontactdate)"
    }

    