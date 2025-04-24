<#  
##########################################################################################################################################
.TITLE          :   REST-Notifications



.FUNCTION       :   Generate a windows event in case of a cloud notification

.PARAMETERS     :    
             		mandatory: 
                        client_id         : ID for Citrix cloud API access - see "Get started with Citrix cloud API" https://developer.cloud.com/explore-more-apis-and-sdk/cloud-services-platform/citrix-cloud-api-overview/docs/get-started-with-citrix-cloud-apis
                        client_secret     : Client Secret for Citrix cloud API access - see "Get started with Citrix cloud API" https://developer.cloud.com/explore-more-apis-and-sdk/cloud-services-platform/citrix-cloud-api-overview/docs/get-started-with-citrix-cloud-apis
                        customer_id       : Customer ID for Citrix cloud API access - see "Get started with Citrix cloud API" https://developer.cloud.com/explore-more-apis-and-sdk/cloud-services-platform/citrix-cloud-api-overview/docs/get-started-with-citrix-cloud-apis
                    non mandatory
                        hours             : Returns notifications that took place in the last specified amount of hours (defaut is 1 hour) 


.REQUIEREMENTS  :     Access to Citrix Cloud over the Internet
                      Create a new source "Citrix Cloud connector" in your application event logs as administrator:
                          [System.Diagnostics.EventLog]::CreateEventSource("Citrix Cloud Connector", 'Application')


.EXAMPLE        :
 
   .\REST_Notifications.ps1 -client_id '########-####-####-####-############' -client_secret '########################' -customer_id '############' -hours 1
.AUTHOR        :     Vincent Rombau - Solution Delivery Architect - Citrix Consulting

.VERSION       : 	 0.4

.HISTORY       :    2021-08-27: Version 0.1 - Initial version created.
                    2021-08-30: Version 0.2 - Send email
                    2021-08-31: Version 0.3 - Create Event Log
                    2021-11-12: Version 0.4 - Get all results not only first 100

#> 


#Read the parameters passed from command line
[int]$hours=1 #default is last hour


$client_id=''
$client_secret=''
$customer_id=''


	$ErrorActionPreference = "Stop"
	$ScriptName = "REST_Notifications"


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

#create an infinite loop
#while($true)
#{
    #get the startdate of the loop
    $sdate=Get-Date
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

        # invoke request to get notifications 
    $myurl = "https://notifications.citrixworkspacesapi.net/"+$CUSTOMER_ID+"/notifications"
    $allresults =@()
    try 
    {
        $result = (Invoke-WebRequest $myurl -Headers @{Authorization = "CwsAuth Bearer=$($token.access_token)"}) #Get first 100 results
        $continuation_token=((($result.RawContent -split '"continuationToken":"')[1]) -split '"}')[0] # extract the Continuation Token from result
        $allresults = ($result | ConvertFrom-Json).items
        while ($continuation_token -ne '') #if the continuation Token is not null, it means that we have more results to get
        {
        $result = (Invoke-WebRequest ($myurl+'?continuationToken='+$continuation_token)  -Headers @{Authorization = "CwsAuth Bearer=$($token.access_token)"}) #get the next results
        $continuation_token=((($result.RawContent -split '"continuationToken":"')[1]) -split '"}')[0] 
        $allresults += ($result | ConvertFrom-Json).items
        }
    }
    catch 
    {
	    "An error occurred."
    }
   
   $allresults |where-object {$_.title -like "*connector*"} |Select-Object title,description 

    <#create events based on notifications sorted by creation date
    foreach ($resp in ($allresults|sort-object "createdDate"))
    {
    $date=([DateTime]($resp.createddate)).ToUniversalTime() #convert date formated like this '2017-08-03T12:30:00.000Z' into someting we can easily read.
   
    
    if (((get-date)-$date).totalhours -le $hours) #only log notifications from delay (default is one hour) 
    {
    switch -wildcard ($resp)
        {
        {($resp.title -match "A Citrix Connector Update is scheduled to occur")}   {Write-EventLog -LogName "Application" -Source "Citrix Cloud Connector" -EventID 3001 -EntryType 'information' -Message ($date.ToString() +" "+ $resp.description) -Category 1 -RawData 10,20}
        {($resp.title -match "A Citrix Connector Update has started")}             {Write-EventLog -LogName "Application" -Source "Citrix Cloud Connector" -EventID 3002 -EntryType 'information' -Message ($date.ToString()  + " "+ $resp.description) -Category 1 -RawData 10,20}
        {($resp.title -match "has been offline")}                                  {Write-EventLog -LogName "Application" -Source "Citrix Cloud Connector" -EventID 3003 -EntryType 'information' -Message ($date.ToString() + " "+ $resp.title + $resp.description) -Category 1 -RawData 10,20}
        }
    }
    }
    #get round up of duration of the loop in seconds
    $duration=[Math]::ceiling(((get-date)-$sdate).TotalSeconds)
    Start-Sleep -s (3600*$hours-$duration)  #amount of hours less time used to run the script to be sure that we don't miss any notification due to the duration of the script
}
#>