Class HS.Local.Demo.FHIR.Landing Extends %CSP.Page
{

/// ----------------------------------------------------------------------------
/// Demo Example for InterSystems IRIS for Health
/// 
/// This class is part of the "Von FHIR zur Insight" demo set.
/// It is intended for demonstration and educational purposes only.
/// 
/// ⚠️ Not production-ready. Do not use with real patient data.
/// All datasets used are synthetic.
/// ----------------------------------------------------------------------------
ClassMethod OnPage() As %Status
{
  &html<<!doctype html><html><head><meta charset="utf-8">
  <title>FHIR Demo – Beispiele</title>

    <script id="demo-data" type="application/json">
  {
    "base": "/i4h20251/csp/healthshare/staging",
    "items": [
      {
        "title": "Management Portal",
        "desc": "",
        "href": "/EnsPortal.ProductionConfig.zen?PRODUCTION=STAGINGPKG.FoundationProduction",
        "tags": ["Dashboard","Allgemein"]
      },
      {
        "title": "Patient Dashboard",
        "desc": "Übersicht Patient, Vitals, Conditions, Meds, Allergien, Encounters, Observations.",
        "href": "/HS.Local.Demo.FHIR.PatientCard.cls?id=2",
        "tags": ["NoLib","Patient","Dashboard","Allgemein"]
      },
      {
        "title": "Blutdruck-Trend",
        "desc": "Zeitliche Entwicklung von Systole/Diastole (LOINC 55284-4).",
        "href": "/HS.Local.Demo.FHIR.BPTrend.cls?id=2",
        "tags": ["Lib","Observation","Vitals","Chart"]
      },
      {
        "title": "Referenz-Graph",
        "desc": "Ressourcen-Referenzen im Bundle als Netzwerk (vis.js).",
        "href": "/HS.Local.Demo.FHIR.RefGraph.cls?id=2",
        "tags": ["Lib","Graph","Bundle","Navigation"]
      },
      {
        "title": "JSON Tree",
        "desc": "FHIR-Bundle als aufklappbarer Baum (details/summary).",
        "href": "/HS.Local.Demo.FHIR.TreeView.cls?p=Patient/2/$everything",
        "tags": ["NoLib","Bundle","Inhalt","Debug"]
      },
      {
        "title": "Medikationsverlauf",
        "desc": "MedicationStatement zeitlich sortiert als einfache Liste.",
        "href": "/HS.Local.Demo.FHIR.MedsTimeline.cls?id=2",
        "tags": ["NoLib","Medication","Timeline"]
      },
      {
        "title": "Timeline",
        "desc": "MedicationStatement zeitlich sortiert als einfache Liste.",
        "href": "/HS.Local.Demo.FHIR.Timeline.cls?id=2",
        "tags": ["Lib","Timeline"]
      }
    ]
  }
  </script>


  <meta name="viewport" content="width=device-width,initial-scale=1">
  <style>
    :root{--b:#e7e7e7;--m:#666;--bg:#fff}
    body{margin:0;font-family:system-ui,Segoe UI,Arial;background:var(--bg);color:#222}
    header{padding:18px 20px;border-bottom:1px solid var(--b);display:flex;gap:12px;flex-wrap:wrap;align-items:center}
    header h1{font-size:20px;margin:0}
    .muted{color:var(--m)}
    .wrap{max-width:1100px;margin:0 auto;padding:16px 20px}
    .controls{display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin:8px 0 16px}
    .controls input{padding:8px 10px;border:1px solid var(--b);border-radius:8px;min-width:260px}
    .controls select{padding:8px 10px;border:1px solid var(--b);border-radius:8px}
    .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:14px}
    .card h3{margin:0;font-size:16px}
    .desc{font-size:13px;color:#333}
    .tags{display:flex;flex-wrap:wrap;gap:6px}
    .tag{font-size:11px;color:#444;border:1px solid var(--b);border-radius:999px;padding:2px 8px;background:#fafafa}
    /* Card: keep normal flow for content, reserve bottom space for the button */
    .card{
    border:1px solid var(--b);
    border-radius:12px;
    padding:14px 14px 58px;   /* ⬅ bottom padding reserves space for the button */
    background:#fff;
    display:flex;
    flex-direction:column;
    gap:8px;
    position:relative;        /* ⬅ anchor for absolute button */
    /* remove any justify-content:space-between from earlier */
    }

    /* Button wrapper pinned to bottom-right */
    .links{
    position:absolute;
    right:14px;
    bottom:14px;
    /* no margins needed; it won’t affect layout of content/tags */
    }
    .btn{display:inline-block;font-size:13px;border:1px solid var(--b);border-radius:8px;padding:6px 10px;background:#f7f7f7;text-decoration:none;color:#111}
    .foot{margin-top:8px;font-size:12px;color:var(--m)}
    .sep{height:1px;background:var(--b);margin:10px 0}
  </style>
  </head><body>
  <header>
    <h1>FHIR Demo – Beispiele</h1>
    <span class="muted" id="srcInfo">Quelle: eingebettetes JSON</span>
  </header>

  <div class="wrap">
    <div class="controls">
      <input id="q" type="text" placeholder="Suchen (Titel, Beschreibung, Tags) …">
      <select id="tagSel"><option value="">Alle Tags</option></select>
    </div>
    <div class="grid" id="grid">Lade…</div>
    <div class="foot" id="count"></div>
  </div>




  <script type="text/javascript">
  (async ()=>{
    const grid = document.getElementById("grid");
    const count = document.getElementById("count");
    const q = document.getElementById("q");
    const tagSel = document.getElementById("tagSel");
    const srcInfo = document.getElementById("srcInfo");

    // Optional: ?data=<url> lädt externes JSON
    const dataURL = new URL(location.href).searchParams.get("data");
    let cfg;
    try{
      if (dataURL){
        const r = await fetch(dataURL, {cache:"no-store"});
        if(!r.ok) throw new Error("HTTP "+r.status);
        cfg = await r.json();
        srcInfo.textContent = "Quelle: " + dataURL;
      } else {
        cfg = JSON.parse(document.getElementById("demo-data").textContent);
      }
    }catch(e){
      grid.textContent = "Fehler beim Laden der Konfiguration: " + (e?.message || e);
      console.error(e);
      return;
    }

    const base = (cfg.base || "").replace(/\/$/,"");
    const items = Array.isArray(cfg.items) ? cfg.items : [];

    // Tag-Set füllen
    const tagSet = new Set();
    items.forEach(it => (it.tags||[]).forEach(t => tagSet.add(t)));
    [...tagSet].sort().forEach(t=>{
      const opt=document.createElement("option"); opt.value=t; opt.textContent=t; tagSel.appendChild(opt);
    });

    function matches(it, needle, tag){
      const hay = [it.title||"", it.desc||"", (it.tags||[]).join(" ")].join(" ").toLowerCase();
      const okTag = !tag || (it.tags||[]).includes(tag);
      return (!needle || hay.includes(needle)) && okTag;
    }

    function render(){
      const needle = q.value.trim().toLowerCase();
      const tag = tagSel.value || "";
      const out = items.filter(it => matches(it, needle, tag));

      grid.innerHTML = out.map(it=>{
        const href = (it.href||"").startsWith("/") ? base + it.href : it.href || "#";
        const tags = (it.tags||[]).map(t=>`<span class="tag">${t}</span>`).join(" ");
        const ext = true; ///^https?:\/\//i.test(href);
        const target = ext ? ` target="_blank" rel="noopener"` : "";
        return `
          <div class="card">
            <h3>${it.title||"Ohne Titel"}</h3>
            <div class="desc">${it.desc||""}</div>
            <div class="tags">${tags}</div>
            <div class="links">
              <a class="btn" href="${href}"${target}>Öffnen</a>
            </div>
          </div>`;
      }).join("");

      if (!out.length) grid.innerHTML = `<div class="muted">Keine Einträge gefunden.</div>`;
      count.textContent = `${out.length} von ${items.length} Einträgen`;
    }

    q.addEventListener("input", render);
    tagSel.addEventListener("change", render);
    render();
  })();
  </script>
    #(##class(HS.Local.Demo.FHIR.Utils).Footer())#
  </body></html>>
  Quit $$$OK
}

}
