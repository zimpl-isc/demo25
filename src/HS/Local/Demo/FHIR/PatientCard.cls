/// ----------------------------------------------------------------------------
/// Demo Example for InterSystems IRIS for Health
/// 
/// This class is part of the "Von FHIR zur Insight" demo set.
/// It is intended for demonstration and educational purposes only.
/// 
/// ⚠️ Not production-ready. Do not use with real patient data.
/// All datasets used are synthetic.
/// ----------------------------------------------------------------------------
Class HS.Local.Demo.FHIR.PatientCard Extends %CSP.Page
{

ClassMethod OnPage() As %Status
{
  set id = ##class(HS.Local.Demo.FHIR.Utils).UrlParam("id",2)

  &html<<!doctype html><html><head><meta charset="utf-8">
  <title>Patient Dashboard</title>
  <style>
    :root{--b:#e7e7e7;--m:#666}
    body{font-family:system-ui,Segoe UI,Arial;padding:20px;margin:0}
    h2{margin:0 0 10px}
    .wrap{max-width:1100px;margin:0 auto}
    .row{display:flex;gap:16px;flex-wrap:wrap}
    .card{border:1px solid var(--b);border-radius:12px;padding:16px;background:#fff}
    .card.sm{padding:12px}
    .muted{color:var(--m)}
    .table{border-collapse:collapse;width:100%}
    .table th,.table td{border:1px solid var(--b);padding:6px 8px;text-align:left}
    details{border:1px solid var(--b);border-radius:10px;margin:12px 0}
    summary{cursor:pointer;padding:10px 12px;font-weight:600}
    details .content{padding:0 12px 12px}
    .kv{display:grid;grid-template-columns:160px 1fr;gap:6px 10px}
    .pill{display:inline-block;border:1px solid var(--b);border-radius:999px;padding:2px 8px;margin-right:6px}
    .vitals{display:grid;grid-template-columns:repeat(4,minmax(140px,1fr));gap:10px}
    .vital{border:1px solid var(--b);border-radius:10px;padding:10px 12px}
    .vital h4{margin:0 0 6px;font-size:14px;color:#333}
    .controls{display:flex;gap:8px;align-items:center;margin:6px 0 16px}
    .controls button{padding:6px 10px;border:1px solid var(--b);background:#fafafa;border-radius:6px;cursor:pointer}
    .controls input{padding:6px 8px;border:1px solid var(--b);border-radius:6px;min-width:260px}
    .warn{color:#b00020}
  </style>
  </head><body>
  <div class="wrap">
    <h2>Patient Dashboard</h2>
    <div class="muted" id="src"></div>

    <div class="controls">
      <button id="exp">Alles aufklappen</button>
      <button id="col">Alles zuklappen</button>
      <input id="filter" type="text" placeholder="Filter (Text enthält …)">
      <span id="msg" class="warn"></span>
    </div>

    <div class="card" id="summary">Lade Patient …</div>

    <div class="row" style="margin-top:12px;">
      <div class="card sm" style="flex:1;min-width:320px">
        <h3 style="margin:0 0 10px">Vitals (neueste)</h3>
        <div class="vitals" id="vitals"></div>
      </div>
    </div>

    <details>
      <summary>Identifier, Kontakt & Adresse</summary>
      <div class="content">
        <div class="kv" id="demokv"></div>
      </div>
    </details>

    <details>
      <summary>Conditions</summary>
      <div class="content">
        <table class="table"><thead><tr>
          <th>Code</th><th>Text</th><th>Onset</th><th>Status</th>
        </tr></thead><tbody id="condrows"><tr><td colspan="4" class="muted">–</td></tr></tbody></table>
      </div>
    </details>

    <details>
      <summary>Medication Statements</summary>
      <div class="content">
        <table class="table"><thead><tr>
          <th>Medikation</th><th>Status</th><th>Zeitraum</th>
        </tr></thead><tbody id="medrows"><tr><td colspan="3" class="muted">–</td></tr></tbody></table>
      </div>
    </details>

    <details>
      <summary>Allergien</summary>
      <div class="content">
        <table class="table"><thead><tr>
          <th>Substanz</th><th>Reaktion</th><th>Schwere</th><th>Status</th>
        </tr></thead><tbody id="allrows"><tr><td colspan="4" class="muted">–</td></tr></tbody></table>
      </div>
    </details>

    <details>
      <summary>Encounters</summary>
      <div class="content">
        <table class="table"><thead><tr>
          <th>Datum</th><th>Klasse</th><th>Typ</th><th>Status</th>
        </tr></thead><tbody id="encrows"><tr><td colspan="4" class="muted">–</td></tr></tbody></table>
      </div>
    </details>

    <details>
      <summary>Observations (letzte 50)</summary>
      <div class="content">
        <table class="table"><thead><tr>
          <th>Datum</th><th>Code</th><th>Text</th><th>Wert</th>
        </tr></thead><tbody id="obsrows"><tr><td colspan="4" class="muted">–</td></tr></tbody></table>
      </div>
    </details>
  </div>

  <script type="text/javascript">
  (async ()=>{
    const idFromServer = #(id)#;
    const id = new URL(location.href).searchParams.get("id") || String(idFromServer);
    const srcEl = document.getElementById("src");
    const msgEl = document.getElementById("msg");

    const proxy = `HS.Local.Demo.FHIR.Utils.cls?p=Patient/${encodeURIComponent(id)}/$everything&_count=200`;
    srcEl.textContent = "Quelle: " + proxy;

    const esc = s => {
      if (s === 0) return "0";
      if (s === false) return "false";
      if (s == null || s === "") return "—";
      return String(s).replace(/[&<>]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;"}[c]));
    };
    const get = (o,p) => p.split(".").reduce((a,k)=>a?.[k],o);
    const show = v => esc(v);
    const pick = (bundle,type) => (bundle.entry||[]).map(e=>e.resource||{}).filter(r=>r.resourceType===type);

    function latestObservationByCode(obs, codes){
      const byDate = o => Date.parse(o.effectiveDateTime || o.issued || "") || -1;
      const sorted = obs.slice().sort((a,b)=>byDate(b)-byDate(a));
      for(const o of sorted){
        if (o.code?.coding?.some(x=>codes.includes(x.code)) && o.valueQuantity?.value!=null)
          return { when:o.effectiveDateTime||o.issued||"", value:o.valueQuantity.value, unit:o.valueQuantity.unit||"" };
        if (o.code?.coding?.some(x=>x.code==="55284-4") && Array.isArray(o.component)) {
          const out = {};
          for (const c of o.component) {
            const codesHere = (c.code?.coding||[]).map(x=>x.code);
            if (codesHere.includes("8480-6") && c.valueQuantity?.value!=null) out.sys = c.valueQuantity;
            if (codesHere.includes("8462-4") && c.valueQuantity?.value!=null) out.dia = c.valueQuantity;
          }
          if (out.sys || out.dia) return { when:o.effectiveDateTime||o.issued||"", bp:out };
        }
      }
      return null;
    }

    try{
      const r = await fetch(proxy,{cache:"no-store"});
      if(!r.ok) throw new Error("HTTP "+r.status);
      const bundle = await r.json();

      const patient = pick(bundle,"Patient")[0] || {};
      const nameObj = patient.name?.[0] || {};
      const fullName = [ (nameObj.given||[]).join(" "), nameObj.family ].filter(Boolean).join(" ") || id;

      document.getElementById("summary").innerHTML = `
        <h3 style="margin:0 0 8px">${esc(fullName)}</h3>
        <div class="kv">
          <div class="muted">Identifier</div><div>${show(get(patient,"identifier.0.value"))}</div>
          <div class="muted">Geschlecht</div><div>${show(patient.gender)}</div>
          <div class="muted">Geburtsdatum</div><div>${show(patient.birthDate)}</div>
          ${patient.maritalStatus?`<div class="muted">Familienstand</div><div>${show(get(patient,"maritalStatus.text") || get(patient,"maritalStatus.coding.0.display"))}</div>`:""}
        </div>`;

      const demokv=document.getElementById("demokv");
      const idents=(patient.identifier||[]).map(i=>`${esc(i.system||"")} ${i.value?`<span class="pill">${esc(i.value)}</span>`:""}`).filter(Boolean).join("<br>")||"—";
      const tels=(patient.telecom||[]).map(t=>`${esc(t.system||"")}: ${esc(t.value||"")}`).filter(Boolean).join("<br>")||"—";
      const addrs=(patient.address||[]).map(a=>{
        const line=(a.line||[]).join(" ");
        const city=a.city||""; const pc=a.postalCode||"";
        const parts=[line,[pc,city].filter(Boolean).join(" ")].filter(Boolean);
        return parts.length?`${esc(parts[0])}${parts[1]?"<br>"+esc(parts[1]):""}`:"";
      }).filter(Boolean).join("<hr>")||"—";
      demokv.innerHTML=`<div class="muted">Identifiers</div><div>${idents}</div>
        <div class="muted">Kontakt</div><div>${tels}</div>
        <div class="muted">Adresse</div><div>${addrs}</div>`;

      const conds=pick(bundle,"Condition");
      document.getElementById("condrows").innerHTML=conds.length?conds.map(c=>`<tr>
        <td>${esc(get(c,"code.coding.0.code")||"")}</td>
        <td>${esc(get(c,"code.text")||get(c,"code.coding.0.display")||"")}</td>
        <td>${esc(get(c,"onsetDateTime")||get(c,"onsetAge.value")||"—")}</td>
        <td>${esc(get(c,"clinicalStatus.text")||get(c,"clinicalStatus.coding.0.code")||"—")}</td></tr>`).join("")
        :`<tr><td colspan="4" class="muted">Keine Bedingungen</td></tr>`;

      const meds=pick(bundle,"MedicationStatement");
      document.getElementById("medrows").innerHTML=meds.length?meds.map(m=>{
        const start=get(m,"effectivePeriod.start")||get(m,"dateAsserted")||"";
        const end=get(m,"effectivePeriod.end")||"";
        const period=start?`${esc(start)}${end?" → "+esc(end):""}`:"—";
        return `<tr><td>${esc(get(m,"medicationCodeableConcept.text")||get(m,"medicationCodeableConcept.coding.0.display")||"Medikation")}</td>
          <td>${esc(m.status||"—")}</td><td>${period}</td></tr>`;
      }).join(""):`<tr><td colspan="3" class="muted">Keine Medikamente</td></tr>`;

      const alls=pick(bundle,"AllergyIntolerance");
      document.getElementById("allrows").innerHTML=alls.length?alls.map(a=>`<tr>
        <td>${esc(get(a,"code.text")||get(a,"code.coding.0.display")||"—")}</td>
        <td>${esc(get(a,"reaction.0.description")||"—")}</td>
        <td>${esc(get(a,"reaction.0.severity")||"—")}</td>
        <td>${esc(a.clinicalStatus?.text||a.clinicalStatus?.coding?.[0]?.code||"—")}</td></tr>`).join("")
        :`<tr><td colspan="4" class="muted">Keine Allergien</td></tr>`;

      const encs=pick(bundle,"Encounter");
      document.getElementById("encrows").innerHTML=encs.length?encs.map(en=>`<tr>
        <td>${esc(get(en,"period.start")||"—")}</td>
        <td>${esc(get(en,"class.code")||"—")}</td>
        <td>${esc(get(en,"type.0.text")||get(en,"type.0.coding.0.display")||"—")}</td>
        <td>${esc(en.status||"—")}</td></tr>`).join("")
        :`<tr><td colspan="4" class="muted">Keine Encounters</td></tr>`;

      const obs=pick(bundle,"Observation").sort((a,b)=>(Date.parse(b.effectiveDateTime||b.issued||"")||-1)-(Date.parse(a.effectiveDateTime||a.issued||"")||-1)).slice(0,50);
      document.getElementById("obsrows").innerHTML=obs.length?obs.map(o=>{
        const text=get(o,"code.text")||get(o,"code.coding.0.display")||"";
        let val="";
        if(o.valueQuantity?.value!=null) val=`${o.valueQuantity.value} ${o.valueQuantity.unit||""}`.trim();
        else if(Array.isArray(o.component)){
          const parts=[];
          for(const c of o.component){
            const t=get(c,"code.coding.0.display")||get(c,"code.text")||"Komponente";
            const v=c.valueQuantity?.value; const u=c.valueQuantity?.unit||"";
            if(v!=null) parts.push(`${t}: ${v} ${u}`.trim());
          }
          val=parts.join("; ");
        } else if(o.valueString) val=o.valueString;
        return `<tr><td>${esc(o.effectiveDateTime||o.issued||"—")}</td>
          <td>${esc(get(o,"code.coding.0.code")||"")}</td><td>${esc(text||"—")}</td><td>${esc(val||"—")}</td></tr>`;
      }).join(""):`<tr><td colspan="4" class="muted">Keine Observations</td></tr>`;

      // vitals tiles
      const latest=codes=>latestObservationByCode(obs,codes);
      const tiles=[];
      const bp=latest(["55284-4"]);
      if(bp?.bp&&(bp.bp.sys?.value!=null||bp.bp.dia?.value!=null)){
        const sys=bp.bp.sys?.value??"—"; const dia=bp.bp.dia?.value??"—";
        tiles.push(`<div class="vital"><h4>Blutdruck</h4><div>${sys}/${dia} mmHg</div><div class="muted">${esc(bp.when||"—")}</div></div>`);
      }
      const hr=latest(["8867-4"]);
      if(hr&&hr.value!=null) tiles.push(`<div class="vital"><h4>Puls</h4><div>${esc(hr.value)} ${esc(hr.unit||"")}</div><div class="muted">${esc(hr.when||"—")}</div></div>`);
      const bmi=latest(["39156-5"]);
      if(bmi&&bmi.value!=null) tiles.push(`<div class="vital"><h4>BMI</h4><div>${esc(bmi.value)} ${esc(bmi.unit||"")}</div><div class="muted">${esc(bmi.when||"—")}</div></div>`);
      const temp=latest(["8310-5"]);
      if(temp&&temp.value!=null) tiles.push(`<div class="vital"><h4>Temperatur</h4><div>${esc(temp.value)} ${esc(temp.unit||"")}</div><div class="muted">${esc(temp.when||"—")}</div></div>`);
      document.getElementById("vitals").innerHTML=tiles.length?tiles.join(""):`<div class="muted">Keine Vitaldaten verfügbar.</div>`;

      // controls
      document.getElementById("exp").onclick=()=>document.querySelectorAll("details").forEach(d=>d.open=true);
      document.getElementById("col").onclick=()=>document.querySelectorAll("details").forEach(d=>d.open=false);
      const filter=document.getElementById("filter");
      filter.addEventListener("input",()=>{
        const needle=filter.value.trim().toLowerCase();
        const rows=document.querySelectorAll("#condrows tr,#medrows tr,#allrows tr,#encrows tr,#obsrows tr");
        rows.forEach(tr=>tr.style.display=needle?(tr.textContent.toLowerCase().includes(needle)?"":"none"):"");
      });
    }catch(e){
      msgEl.textContent="Fehler: "+(e?.message||e);
      console.error(e);
    }
  })();
  </script>
  #(##class(HS.Local.Demo.FHIR.Utils).Footer())#
  </body></html>>
  Quit $$$OK
}

}
