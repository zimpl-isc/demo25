/// ----------------------------------------------------------------------------
/// Demo Example for InterSystems IRIS for Health
/// 
/// This class is part of the "Von FHIR zur Insight" demo set.
/// It is intended for demonstration and educational purposes only.
/// 
/// ⚠️ Not production-ready. Do not use with real patient data.
/// All datasets used are synthetic.
/// ----------------------------------------------------------------------------
Class HS.Local.Demo.FHIR.Timeline Extends %CSP.Page
{

ClassMethod OnPage() As %Status
{
  // read ?id=..., default 2
  set id = ##class(HS.Local.Demo.FHIR.Utils).UrlParam("id",2)

  &html<<!doctype html><html><head><meta charset="utf-8">
  <title>FHIR Timeline</title>
  <meta name="viewport" content="width=device-width,initial-scale=1">

  <link rel="stylesheet" href="https://unpkg.com/vis-timeline@7.7.0/styles/vis-timeline-graph2d.min.css"/>
  <script src="https://unpkg.com/vis-timeline@7.7.0/standalone/umd/vis-timeline-graph2d.min.js"></script>

  <style>
    :root{--b:#e7e7e7;--m:#666}
    body{margin:0;font-family:system-ui,Segoe UI,Arial}
    header{padding:12px 16px;border-bottom:1px solid var(--b);display:flex;gap:10px;align-items:center;flex-wrap:wrap}
    header h2{margin:0;font-size:18px}
    .muted{color:var(--m)}
    .wrap{max-width:1200px;margin:0 auto;padding:12px 16px}
    .controls{display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin:6px 0 12px}
    .controls input,.controls select{padding:6px 8px;border:1px solid var(--b);border-radius:8px}
    .controls label{display:inline-flex;align-items:center;gap:6px}
    #timeline{height:70vh;border:1px solid var(--b);border-radius:10px}
    .legend{font-size:12px;color:#333;display:flex;gap:10px;flex-wrap:wrap;margin:6px 0}
    .chip{border:1px solid var(--b);border-radius:999px;padding:2px 8px;background:#fafafa}
  </style>
  </head><body>
  <header>
    <h2>FHIR Timeline</h2>
    <span class="muted" id="src">Quelle: –</span>
  </header>
  <div class="wrap">
    <div class="controls">
      <label><input type="checkbox" id="showEnc" checked> Encounters</label>
      <label><input type="checkbox" id="showMed" checked> Medications</label>
      <label><input type="checkbox" id="showObs" checked> Observations</label>
      <select id="obsFilter">
        <option value="">Observations: alle</option>
        <option value="55284-4">BP Panel (55284-4)</option>
        <option value="8867-4">Herzfrequenz (8867-4)</option>
        <option value="8310-5">Temperatur (8310-5)</option>
        <option value="39156-5">BMI (39156-5)</option>
        <option value="718-7">HbA1c (718-7)</option>
      </select>
      <input id="textFilter" type="text" placeholder="Textfilter (Titel/Code/Wert)">
      <button id="fit">Fit</button>
      <span id="msg" class="muted"></span>
    </div>

    <div class="legend">
      <span class="chip">Encounters = Zeitspannen</span>
      <span class="chip">Medications = Zeitspannen</span>
      <span class="chip">Observations = Punkte</span>
    </div>

    <div id="timeline"></div>
  </div>

  <script type="text/javascript">
  (async ()=>{
    const id = new URL(location.href).searchParams.get("id") || String(#(id)#);
    const proxy = `HS.Local.Demo.FHIR.Utils.cls?p=Patient/${encodeURIComponent(id)}/$everything&_count=500`;
    document.getElementById("src").textContent = "Quelle: " + proxy;

    const showEnc = document.getElementById("showEnc");
    const showMed = document.getElementById("showMed");
    const showObs = document.getElementById("showObs");
    const obsFilter = document.getElementById("obsFilter");
    const textFilter = document.getElementById("textFilter");
    const fitBtn = document.getElementById("fit");
    const msg = document.getElementById("msg");

    const esc = s => String(s??"").replace(/[&<>]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;"}[c]));
    const get = (o,p) => p.split(".").reduce((a,k)=>a?.[k],o);
    const parseDate = (s) => {
      if (!s) return null;
      // Accept yyyy, yyyy-mm, yyyy-mm-dd, or full ISO timestamps
      try { const d = new Date(s); return isNaN(d) ? null : d; } catch { return null; }
    };

    function pick(bundle, type){
      return (bundle.entry||[]).map(e=>e.resource||{}).filter(r=>r.resourceType===type);
    }

    function labelObservation(o){
      const code = get(o,"code.coding.0.code") || "";
      const disp = get(o,"code.text") || get(o,"code.coding.0.display") || code;
      // Top-level value or component summary
      let val = "";
      if (o.valueQuantity?.value!=null) val = `${o.valueQuantity.value} ${o.valueQuantity.unit||""}`.trim();
      else if (Array.isArray(o.component)) {
        const parts = [];
        for (const c of o.component){
          const t = get(c,"code.coding.0.display") || get(c,"code.text") || "";
          const v = c.valueQuantity?.value; const u = c.valueQuantity?.unit||"";
          if (v!=null) parts.push(`${t||"Komponente"}: ${v} ${u}`.trim());
        }
        val = parts.join("; ");
      } else if (o.valueString) val = o.valueString;
      return { code, text: disp, value: val };
    }

    function buildItems(bundle){
      const items = [];
      const groups = new vis.DataSet([
        { id: "enc", content: "Encounters" },
        { id: "med", content: "Medications" },
        { id: "obs", content: "Observations" }
      ]);

      // Encounters -> range
      for (const en of pick(bundle,"Encounter")){
        const s = parseDate(get(en,"period.start"));
        const e = parseDate(get(en,"period.end")) || s;
        if (!s) continue;
        const typ = get(en,"type.0.text") || get(en,"type.0.coding.0.display") || "";
        const cls = get(en,"class.code") || "";
        items.push({
          id: "enc:"+ (en.id || Math.random()),
          group: "enc",
          start: s,
          end: e,
          type: "range",
          content: esc(typ || cls || "Encounter"),
          title: `Encounter<br>${esc(typ||cls||"")}${e?"":"<br>(Zeitpunkt)"}`,
          _raw: en
        });
      }

      // MedicationStatement -> range (effectivePeriod) or instant (dateAsserted)
      for (const m of pick(bundle,"MedicationStatement")){
        const start = parseDate(get(m,"effectivePeriod.start") || get(m,"dateAsserted"));
        const end = parseDate(get(m,"effectivePeriod.end"));
        if (!start) continue;
        const label = get(m,"medicationCodeableConcept.text") || get(m,"medicationCodeableConcept.coding.0.display") || "Medication";
        items.push({
          id: "med:"+ (m.id || Math.random()),
          group: "med",
          start, end: end || start,
          type: end ? "range" : "point",
          content: esc(label),
          title: `Medication<br>${esc(label)}${end?`<br>${esc(get(m,"status")||"")}`:``}`,
          _raw: m
        });
      }

      // Observations -> point at effectiveDateTime/issued
      for (const o of pick(bundle,"Observation")){
        const t = parseDate(o.effectiveDateTime || o.issued);
        if (!t) continue;
        const { code, text, value } = labelObservation(o);
        items.push({
          id: "obs:"+ (o.id || Math.random()),
          group: "obs",
          start: t,
          type: "point",
          content: esc(text || code || "Observation"),
          title: `Observation<br>${esc(text || code || "")}${value?`<br><b>${esc(value)}</b>`:""}`,
          _code: code,
          _value: (text + " " + value).toLowerCase(),
          _raw: o
        });
      }

      return { groups, items: new vis.DataSet(items) };
    }

    function applyFilters(items){
      const wantEnc = showEnc.checked;
      const wantMed = showMed.checked;
      const wantObs = showObs.checked;
      const code = obsFilter.value || "";
      const tneedle = (textFilter.value||"").toLowerCase();

      return items.get().filter(it=>{
        if (it.group==="enc" && !wantEnc) return false;
        if (it.group==="med" && !wantMed) return false;
        if (it.group==="obs"){
          if (!wantObs) return false;
          if (code && it._code !== code) return false;
          if (tneedle && !( (it.content||"").toLowerCase().includes(tneedle) || (it._value||"").includes(tneedle) )) return false;
        } else if (tneedle){
          // allow text filter to affect all
          const hay = (it.content||"").toLowerCase() + " " + (it.title||"").toLowerCase();
          if (!hay.includes(tneedle)) return false;
        }
        return true;
      });
    }

    try{
      const res = await fetch(proxy,{cache:"no-store"});
      if(!res.ok) throw new Error("HTTP "+res.status);
      const bundle = await res.json();

      const { groups, items } = buildItems(bundle);
      const container = document.getElementById("timeline");
      const timeline = new vis.Timeline(container, items, {
        groupOrder: 'content',
        stack: true,
        selectable: true,
        multiselect: false,
        zoomKey: 'ctrlKey',
        orientation: 'top',
        tooltip: { followMouse: true },
        maxHeight: "70vh"
      });
      timeline.setGroups(groups);

      // filtering: redraw with subset
      function redraw(){
        const subset = applyFilters(items);
        const ds = new vis.DataSet(subset);
        timeline.setItems(ds);
        msg.textContent = `${subset.length} Items`;
        // keep a reference for fit
        timeline._currentItems = ds;
      }
      showEnc.onchange = redraw;
      showMed.onchange = redraw;
      showObs.onchange = redraw;
      obsFilter.onchange = redraw;
      textFilter.addEventListener("input", redraw);

      fitBtn.onclick = ()=>{
        const ds = timeline._currentItems || items;
        const arr = ds.get();
        if (arr.length) timeline.fit();
      };

      // initial
      redraw();

    }catch(e){
      document.getElementById("timeline").innerHTML = `<div style="padding:16px;color:#b00020">Fehler: ${esc(e?.message||e)}</div>`;
      console.error(e);
    }
  })();
  </script>
    #(##class(HS.Local.Demo.FHIR.Utils).Footer())#
  </body></html>>
  Quit $$$OK
}

}
