/// ----------------------------------------------------------------------------
/// Demo Example for InterSystems IRIS for Health
/// 
/// This class is part of the "Von FHIR zur Insight" demo set.
/// It is intended for demonstration and educational purposes only.
/// 
/// ⚠️ Not production-ready. Do not use with real patient data.
/// All datasets used are synthetic.
/// ----------------------------------------------------------------------------
Class HS.Local.Demo.FHIR.TreeView Extends %CSP.Page
{

ClassMethod OnPage() As %Status
{
  &html<<!doctype html><html><head><meta charset="utf-8">
  <title>FHIR JSON Tree</title>
  <style>
    :root{--fg:#222;--muted:#666;--b:#e7e7e7;--bg:#fff}
    html,body{height:100%}
    body{margin:0;font-family:system-ui,Segoe UI,Arial;background:var(--bg);color:var(--fg)}
    header{padding:10px 14px;border-bottom:1px solid var(--b);display:flex;gap:10px;align-items:center;flex-wrap:wrap}
    #src{color:var(--muted);font-size:12px}
    #controls button{padding:6px 10px;border:1px solid var(--b);background:#fafafa;border-radius:6px;cursor:pointer}
    #controls input[type="text"]{padding:6px 8px;border:1px solid var(--b);border-radius:6px;min-width:260px}
    main{height:calc(100% - 100px);display:flex;flex-direction:column}
    #tree{padding:1em 2em;overflow:auto;flex:1; margin-left:2em;}
    details{padding-left:12px;border-left:1px dashed #ddd;margin:4px 0}
    summary{cursor:pointer;list-style:none}
    summary::-webkit-details-marker{display:none}
    summary::before {
        content:"+ ";
        color:#888;
        font-weight:600;
        width:1em;
        display:inline-block;
        transition:transform .15s;
        margin-left: -2em;
  }
  >
    write "details[open] > summary::before"
  &html<
   {
    content:"− ";
    color:#000;
  }
    .k{color:#0b6; font-weight:600}
    .t{color:#06c}
    .n{color:#b50}
    .s{color:#a11}
    .m{color:var(--muted)}
    .kv{margin-left:8px}
    .hit mark{background: #ffec7a}
    .chip{display:inline-block;border:1px solid var(--b);border-radius:999px;padding:1px 6px;margin-left:6px;font-size:11px;color:#444;background:#f7f7f7}
  </style>
  </head><body>
  <header>
    <strong>FHIR JSON Tree</strong>
    <div id="controls">
      <button id="expAll">Expand all</button>
      <button id="colAll">Collapse all</button>
      <label style="margin-left:8px;"><input type="checkbox" id="groupEntries" checked> Nach Bundle-Entries gruppieren</label>
      <input id="q" type="text" placeholder="Filter (Schlüssel/Wert enthält …)">
    </div>
    <div id="src"></div>
  </header>
  <main>
    <div id="tree">Lade…</div>
  </main>
  
  <script type="text/javascript">
  (async ()=>{
    // Build proxy URL from our own querystring
    const id = #($get(%request.Data("id",1),2))#;
    const qs = "?p=Patient/"+id+"/$everything";
    const proxy = "HS.Local.Demo.FHIR.Utils.cls" + qs;
    document.getElementById("src").textContent = "Quelle: " + proxy;

    // Fetch bundle
    const resp = await fetch(proxy, { cache:"no-store" });
    if(!resp.ok){ document.getElementById("tree").textContent = "Fehler: HTTP " + resp.status; return; }
    const data = await resp.json();

    const tree = document.getElementById("tree");
    tree.innerHTML = ""; // clear

    // Renderer ------------------------------------------------------------
    const esc = s => String(s).replace(/[&<>]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
    const isObj = v => v && typeof v === "object" && !Array.isArray(v);

    function leafLine(key, val){
      let cls="s", txt=JSON.stringify(val);
      if (typeof val==="number") { cls="n"; txt=String(val); }
      else if (typeof val==="boolean") { cls="t"; txt=String(val); }
      else if (val===null) { cls="m"; txt="null"; }
      return `<div><span class="k">${esc(key)}</span>: <span class="${cls}">${esc(txt)}</span></div>`;
    }

    function renderObject(obj){
      const frag = document.createElement("div"); frag.className="kv";
      const keys = Object.keys(obj);
      for (const k of keys){
        const v = obj[k];
        if (isObj(v)){
          const d = document.createElement("details");
          const s = document.createElement("summary");
          s.innerHTML = `<span class="k">${esc(k)}</span> <span class="chip">Object</span>`;
          d.appendChild(s);
          d.appendChild(renderObject(v));
          frag.appendChild(d);
        } else if (Array.isArray(v)){
          const d = document.createElement("details");
          const s = document.createElement("summary");
          s.innerHTML = `<span class="k">${esc(k)}</span> <span class="chip">Array[${v.length}]</span>`;
          d.appendChild(s);
          const wrap = document.createElement("div"); wrap.className="kv";
          v.forEach((it, idx)=>{
            if (isObj(it) || Array.isArray(it)){
              const di = document.createElement("details");
              const si = document.createElement("summary");
              si.innerHTML = `<span class="k">[${idx}]</span>`;
              di.appendChild(si);
              di.appendChild(isObj(it) ? renderObject(it) : renderArray(it));
              wrap.appendChild(di);
            } else {
              const line = document.createElement("div");
              line.innerHTML = leafLine("["+idx+"]", it);
              wrap.appendChild(line);
            }
          });
          d.appendChild(wrap);
          frag.appendChild(d);
        } else {
          const line = document.createElement("div");
          line.innerHTML = leafLine(k, v);
          frag.appendChild(line);
        }
      }
      return frag;
    }

    function renderArray(arr){
      const wrap = document.createElement("div"); wrap.className="kv";
      arr.forEach((it, idx)=>{
        if (isObj(it) || Array.isArray(it)){
          const d = document.createElement("details");
          const s = document.createElement("summary");
          s.innerHTML = `<span class="k">[${idx}]</span>`;
          d.appendChild(s);
          d.appendChild(isObj(it) ? renderObject(it) : renderArray(it));
          wrap.appendChild(d);
        } else {
          const line = document.createElement("div");
          line.innerHTML = leafLine("["+idx+"]", it);
          wrap.appendChild(line);
        }
      });
      return wrap;
    }

    function entryLabel(res, fallback){
      const rt = res.resourceType || "Resource";
      const id = res.id ? rt + "/" + res.id : (fallback || rt);
      const name = res.code?.text || res.name?.[0]?.text || res.title || res.display || "";
      return name ? `${id} — ${esc(name)}` : id;
    }

    // Grouped (Entry per resource) vs. raw whole-bundle
    const groupedToggle = document.getElementById("groupEntries");

    function renderBundle(){
      tree.innerHTML="";
      if (groupedToggle.checked && Array.isArray(data.entry)){
        for (const e of data.entry){
          const res = e.resource || {};
          const d = document.createElement("details"); d.open=false;
          const s = document.createElement("summary");
          const label = entryLabel(res, e.fullUrl || "");
          s.innerHTML = `<span class="t">${label}</span>`;
          d.appendChild(s);
          d.appendChild(renderObject(res));
          tree.appendChild(d);
        }
      } else {
        const d = document.createElement("details"); d.open=true;
        const s = document.createElement("summary");
        s.innerHTML = `<span class="t">${esc(data.resourceType || "Bundle")}</span>`;
        d.appendChild(s);
        d.appendChild(renderObject(data));
        tree.appendChild(d);
      }
    }

    renderBundle();

    // Controls ------------------------------------------------------------
    document.getElementById("expAll").onclick = ()=>{
      tree.querySelectorAll("details").forEach(d=>d.open=true);
    };
    document.getElementById("colAll").onclick = ()=>{
      tree.querySelectorAll("details").forEach(d=>d.open=false);
    };
    groupedToggle.onchange = renderBundle;

    // Filter: simple contains-anywhere on textContent
    const q = document.getElementById("q");
    q.addEventListener("input", ()=>{
      const needle = q.value.trim().toLowerCase();
      tree.querySelectorAll(".hit").forEach(el => el.classList.remove("hit"));
      if (!needle){
        // show all
        tree.querySelectorAll("details").forEach(d=>d.style.display="");
        tree.querySelectorAll("div,summary").forEach(el=>el.style.display="");
        return;
      }
      // hide all; show only branches with match
      function matches(el){ return el.textContent.toLowerCase().includes(needle); }
      tree.querySelectorAll("details").forEach(d=>d.style.display="none");
      tree.querySelectorAll("div,summary").forEach(el=>el.style.display="none");
      // Unhide matches and ancestors
      const all = Array.from(tree.querySelectorAll("details,div,summary"));
      for (const el of all){
        if (matches(el)){
          el.classList.add("hit");
          let p = el;
          while (p && p!==tree){
            if (p.tagName==="DETAILS"){ p.style.display=""; p.open=true; }
            else { p.style.display=""; }
            p = p.parentElement;
          }
        }
      }
    });
  })();
  </script>
  #(##class(HS.Local.Demo.FHIR.Utils).Footer())#
  </body></html>>
  Quit $$$OK
}

}
