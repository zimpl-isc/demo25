/// ----------------------------------------------------------------------------
/// Demo Example for InterSystems IRIS for Health
/// 
/// This class is part of the "Von FHIR zur Insight" demo set.
/// It is intended for demonstration and educational purposes only.
/// 
/// ⚠️ Not production-ready. Do not use with real patient data.
/// All datasets used are synthetic.
/// ----------------------------------------------------------------------------
Class HS.Local.Demo.FHIR.MedsTimeline Extends %CSP.Page
{

ClassMethod OnPage() As %Status
{
  set id = ##class(HS.Local.Demo.FHIR.Utils).UrlParam("id","2")

  &html<<!doctype html><html><head><meta charset="utf-8">
  <title>Medication Timeline - #(id)#</title>
  <style>
    body{font-family:system-ui;padding:20px}#w{max-width:700px}
    ul{padding-left:18px} li{margin:6px 0} .m{color:#666}
  </style>
  </head><body>
  <div id="w">
    <h2>Medikationsverlauf</h2>
    <p class="m">Patient: #(id)#</p>
    <ul id="list">Lade…</ul>
    <div id="msg" class="m"></div>
  </div>

  <script type="text/javascript">
  (async ()=>{
    try{
      const id = new URL(location.href).searchParams.get("id") || #( $zcvt(id,"O","JSON") )#;
      const url = `HS.Local.Demo.FHIR.Utils.cls?p=MedicationStatement&subject=Patient/${encodeURIComponent(id)}&_sort=-effective&_count=100`;
      const r = await fetch(url,{cache:"no-store"});
      if(!r.ok) throw new Error("HTTP "+r.status);
      const bundle = await r.json();
      const meds = (bundle.entry||[]).map(e=>e.resource||{});

      const html = meds.length ? meds.map(m=>{
        const name = m.medicationCodeableConcept?.text
                  || m.medicationCodeableConcept?.coding?.[0]?.display
                  || "Unbekannte Medikation";
        const s = m.effectivePeriod?.start || m.dateAsserted || "—";
        const e = m.effectivePeriod?.end || "";
        const status = m.status||"";
        const color = status==="active"?"#0a7":"#666";
        return `<li><span style="color:${color}">${name}</span><small class="m"> (${s}${e? " → "+e:""})</small></li>`;
      }).join("") : `<li class="m">Keine Medikation gefunden</li>`;

      document.getElementById("list").innerHTML = html;
    }catch(e){
      document.getElementById("msg").textContent="Fehler: "+(e?.message||e);
      console.error(e);
    }
  })();
  </script>
  #(##class(HS.Local.Demo.FHIR.Utils).Footer())#
  </body></html>>
  Quit $$$OK
}

}
