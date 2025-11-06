/// ----------------------------------------------------------------------------
/// Demo Example for InterSystems IRIS for Health
/// 
/// This class is part of the "Von FHIR zur Insight" demo set.
/// It is intended for demonstration and educational purposes only.
/// 
/// ⚠️ Not production-ready. Do not use with real patient data.
/// All datasets used are synthetic.
/// ----------------------------------------------------------------------------
Class HS.Local.Demo.FHIR.Utils Extends %CSP.Page
{

/// Instanzname vom FHIR Repository
Parameter FhirRepo = "/csp/healthshare/staging/fhir/r4";

/// Helper method which returns the value for a url parameter in the current request, with a fallback to a default value
ClassMethod UrlParam(pName As %String, pDefault As %String = "") As %String
{
  set v = %request.Get(pName)
  quit $select(v="":pDefault, 1:v)
}

/// Overrides same method from superclass; entrypoint for web requests
ClassMethod OnPage() As %Status
{
    set tRequestPath = "/"_$get(%request.Data("p",1), "Observation")

    for {
        set tParam = $order(%request.Data($get(tParam)))  quit:(tParam="")
        continue:(tParam = "p")
        for {
            set tIdx = $order(%request.Data(tParam, $get(tIdx))) quit:(tIdx="")
            set tQueryString = $select($get(tQueryString)'="":tQueryString_"&", 1:"")_tParam_"="_%request.Data(tParam,tIdx)
        }
    }

    set tSc = ..GetFHIR(tRequestPath, $get(tQueryString), .tResponse)

    if $IsObject(tResponse) {
        write tResponse.%ToJSON()
    } else {
        write tResponse
    }

    return $$$OK
}

ClassMethod GetFHIR(pPath = "/Observation", pQueryString = "", Output pResponse As %DynamicObject) As %Status
{
    #dim tRequest as HS.FHIRServer.API.Data.Request = ##class(HS.FHIRServer.API.Data.Request).%New()
    #dim tResponse as HS.FHIRServer.API.Data.Response
    #dim tException as %Exception.StatusException

    try {

        set tRequest.RequestMethod = "GET"
        set tRequest.RequestPath = pPath
        set tRequest.QueryString = pQueryString
        set tRequest.RequestFormatCode = "JSON"
        set tRequest.ResponseFormatCode = "ANY"
        set tRequest.BaseURL = "https://"_##class(%SYSTEM.INetInfo).LocalHostName()
        set tRequest.LocalBaseURL = tRequest.BaseURL

        #dim tFhirService as %ZHSLIB.Context.NamedInstanceBase
        set tFhirService = ##class(HS.FHIRServer.Service).EnsureInstance(..#FhirRepo)
        do tFhirService.DispatchRequest(tRequest, .tResponse)

        set pResponse = tResponse.Json

    } catch tException {
        set pResponse = {"error":(tException.AsStatus())}
    }


    return $$$OK
}

/// Helper method for demo pages
ClassMethod Footer()
{
    &html<<footer style="font-size:12px;color:#777;margin-top:20px;text-align:center;width:100%;">
  Demo-System · Synthetische Daten · Nicht für produktiven Gebrauch
    </footer>>

    return ""
}

}
