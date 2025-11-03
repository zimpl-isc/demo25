Class HS.Local.Demo.FHIR.Utils Extends %CSP.Page
{

Parameter FhirRepo = "/csp/healthshare/staging/fhir/r4";

ClassMethod UrlParam(pName As %String, pDefault As %String = "") As %String
{
  set v = %request.Get(pName)
  quit $select(v="":pDefault, 1:v)
}

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

}
