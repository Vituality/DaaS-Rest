
#Read the parameters passed from command line
$client_id=''
$client_secret=''
$customer_id=''


	$ErrorActionPreference = "Stop"


try
{
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy 
    {
    public bool CheckValidationResult(
    ServicePoint srvPoint, X509Certificate certificate,
    WebRequest request, int certificateProblem) {return true;}
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
}
catch{}

    # get the bearer token (it expires every hour)
    try 
    {
        $tokenUrl = 'https://api-us.cloud.com/cctrustoauth2/root/tokens/clients'
        $response = Invoke-WebRequest $tokenUrl -Method POST -Body @{
	        grant_type    = "client_credentials"
	        client_id	  = $client_id
	        client_secret = $client_secret
        }
        $token = $response.Content | ConvertFrom-Json
    } 
    catch 
    {
	    "An error occurred."
    }

        # invoke request to get notifications https://developer-docs.citrix.com/en-us/citrix-cloud/citrix-cloud-systemlog/gettingstarted
    $myurl = "https://api-us.cloud.com/systemlog/records"
    $headers = @{
	    Authorization = "CwsAuth Bearer=$($token.access_token)"
	    'Citrix-CustomerId' = $customer_id;
        'Accept' = 'application/json'        
    }
    $allresults =@()
    try 
    {
        $result = (Invoke-WebRequest $myurl -Headers $headers) #Get first 100 results
        $continuation_token=((($result.RawContent -split '"continuationToken":"')[1]) -split '"}')[0] # extract the Continuation Token from result
        $allresults = ($result | ConvertFrom-Json).items
        while ($continuation_token -ne '') #if the continuation Token is not null, it means that we have more results to get
        {
        $result = (Invoke-WebRequest ($myurl+'?continuationToken='+$continuation_token)  -Headers $headers) #get the next results
        $continuation_token=((($result.RawContent -split '"continuationToken":"')[1]) -split '"}')[0] 
        $allresults += ($result | ConvertFrom-Json).items
        }
        $allresults |Select-Object utctimestamp,"message.'en-US'"
    }
    catch 
    {
	    "An error occurred."
    }
   
  