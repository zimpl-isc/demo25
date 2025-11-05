/// ----------------------------------------------------------------------------
/// Demo Example for InterSystems IRIS for Health
/// 
/// This class is part of the "Von FHIR zur Insight" demo set.
/// It is intended for demonstration and educational purposes only.
/// 
/// ⚠️ Not production-ready. Do not use with real patient data.
/// All datasets used are synthetic.
/// ----------------------------------------------------------------------------
Class HS.Local.Demo.FHIR.BPTrend Extends %CSP.Page
{

ClassMethod OnPage() As %Status
{
  set id = ##class(HS.Local.Demo.FHIR.Utils).UrlParam("id","2")

  &html<<!doctype html><html><head><meta charset="utf-8">
  <title>BP Trend - #(id)#</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/luxon@3"></script>
  <script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-luxon@1"></script>
  <style>body{font-family:system-ui;padding:20px}#w{max-width:820px}.m{color:#666}</style>
  </head><body><div id="w">
    <h2>Blutdruck-Trend</h2>
    <p class="m">Patient: #(id)#</p>
    <canvas id="c" height="120"></canvas>
    <div id="msg" class="m"></div>
  </div>

  <script type="text/javascript">
  (async ()=>{
    try{
      const id = new URL(location.href).searchParams.get("id") || #( $zcvt(id,"O","JSON") )#;
      const url = `HS.Local.Demo.FHIR.Utils.cls?p=Observation&patient=${encodeURIComponent(id)}&code=55284-4&_sort=date&_count=200`;
      const r = await fetch(url,{cache:"no-store"});
      if(!r.ok) throw new Error("HTTP "+r.status);
      const bundle = await r.json();

      const SYS="8480-6", DIA="8462-4";
      const toTs = s => { const t = Date.parse(s); return Number.isFinite(t)?t:null; };
      const systolic=[], diastolic=[];
      for(const e of (bundle.entry||[])){
        const o = e.resource||{};
        const ts = toTs(o.effectiveDateTime || o.issued);
        if(ts==null) continue;
        const hasPanel = o.code?.coding?.some(c=>c.code==="55284-4")===true;
        if(hasPanel && Array.isArray(o.component)){
          for(const c of o.component){
            const v=c?.valueQuantity?.value; if(v==null) continue;
            const codes=c?.code?.coding||[];
            if(codes.some(x=>x.code===SYS)) systolic.push({x:ts,y:+v});
            if(codes.some(x=>x.code===DIA)) diastolic.push({x:ts,y:+v});
          }
        }
      }
      systolic.sort((a,b)=>a.x-b.x); diastolic.sort((a,b)=>a.x-b.x);

      const ctx=document.getElementById("c").getContext("2d");
      new Chart(ctx,{
        type:"line",
        data:{datasets:[
          {label:"Systolic (mmHg)",data:systolic},
          {label:"Diastolic (mmHg)",data:diastolic}
        ]},
        options:{
          parsing:false, interaction:{mode:"nearest",intersect:false},
          elements:{point:{radius:3}},
          scales:{
            x:{type:"time", time:{unit:"day", tooltipFormat:"yyyy-LL-dd HH:mm"}, adapters:{date:{zone:"utc"}}, ticks:{source:"data"}},
            y:{title:{display:true,text:"mmHg"}}
          }
        }
      });

      if(!systolic.length && !diastolic.length) document.getElementById("msg").textContent="Keine BP-Daten gefunden.";
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
