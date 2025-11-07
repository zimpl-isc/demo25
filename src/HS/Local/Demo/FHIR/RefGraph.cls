Class HS.Local.Demo.FHIR.RefGraph Extends %CSP.Page
{

ClassMethod OnPage() As %Status
{
  &html<<!doctype html><html><head><meta charset="utf-8">
  <title>FHIR Reference Graph</title>

  <script src="https://unpkg.com/vis-network@9.1.6/dist/vis-network.min.js"></script>
  <link rel="stylesheet" href="https://unpkg.com/vis-network@9.1.6/styles/vis-network.min.css"/>

  <style>
    :root{--border:#eee;--muted:#666}
    body{font-family:system-ui,Segoe UI,Arial;margin:0}
    header{padding:12px 16px;border-bottom:1px solid var(--border)}
    #hint{color:var(--muted);font-size:13px}
    #controls{padding:8px 16px;border-bottom:1px solid var(--border);display:flex;gap:12px;align-items:center;flex-wrap:wrap}
    #graph{height:58vh}
    #log{padding:8px 16px;color:var(--muted);font-size:12px}
    .badge{display:inline-block;padding:2px 6px;border-radius:999px;border:1px solid #ccc;background:#fafafa;font-size:12px}
    #inputArea{padding:12px 16px;border-bottom:1px solid var(--border);display:grid;gap:8px}
    #bundleText{width:100%;height:2em;font-family:ui-monospace,Consolas,Monaco,monospace}
    .row{display:flex;gap:8px;flex-wrap:wrap;align-items:center}
    .grow{flex:1}
    .danger{color:#b00020}
    .muted{color:var(--muted)}
    button{padding:6px 10px}
    .small{font-size:12px}
    #detail{padding:8px 16px;border-top:1px solid var(--border);height:20vh;overflow:auto;font-family:ui-monospace,Consolas,Monaco,monospace;background:#fcfcfc}
    pre{margin:0;white-space:pre-wrap;word-break:break-word}
  </style>

  </head><body>
  <header>
    <h2 style="margin:0">FHIR Reference Graph</h2>
    <div id="log"></div>
  </header>

  <!-- —— New input section: paste/upload OR fetch —— -->
  <div id="inputArea">
    <div class="row">
      <strong>Quelle:</strong>
      <button id="btnFetch">Vom Server laden</button>
      <button id="btnUseText">Eingefügtes JSON nutzen</button>
      <input id="filePick" type="file" accept=".json,application/json"/>
      <span class="muted small">Tipp: Bundle hier einfügen oder Datei wählen.</span>
    </div>
    <textarea id="bundleText" placeholder="FHIR Bundle hier einfügen (JSON)…"></textarea>
    <div class="row small muted">
      <span>Unterstützt: <code>Resource/id</code>, <code>Resource?identifier=…</code>, <code>urn:uuid:…</code>, lokale <code>#Contained</code>-Refs werden ignoriert.</span>
    </div>
  </div>

  <div id="controls">
    <button id="fit">Fit</button>
    <label><input type="checkbox" id="physics" checked> Physics</label>
    <span id="counts" class="badge">0 Knoten · 0 Kanten</span>
    <span id="msg" class="danger"></span>
  </div>

  <div id="graph"></div>
  <div id="detail" class="small"><em class="muted">Wähle einen Knoten, um die Ressource (falls im Bundle vorhanden) zu sehen.</em></div>

  <script type="text/javascript">
  (()=>{
    const id = #($get(%request.Data("id",1),2))#;
    const qs = "?p=Patient/"+id+"/$everything";
    const proxy = "HS.Local.Demo.FHIR.Utils.cls" + qs;

    const el = (id)=>document.getElementById(id);
    const msg = (t)=>{ el("msg").textContent=t||""; };
    const log = (t)=>{ el("log").textContent=t||""; };

    // —— Normalize a Reference into something we can key/route edges by
    function normRef(ref){
      if(!ref) return null;
      if(typeof ref!=="string") return null;
      if(ref.startsWith("#")) return null; // contained
      // strip hash fragments
      ref = ref.split("#")[0];

      // Keep logical references (with query) intact
      if(ref.includes("?")) return ref;

      // Accept urn:uuid:...
      if(ref.startsWith("urn:uuid:")) return ref;

      // Canonical Resource/id
      const m = ref.match(/^([A-Za-z][A-Za-z0-9]+)\/([^\/\?\s]+)$/);
      if(m) return m[1]+"/"+m[2];

      return null;
    }

    function nodeId(rt,id){ return rt+"/"+id; }

    function walkForRefs(obj, addEdge){
      if(!obj || typeof obj!=="object") return;
      if(Array.isArray(obj)){ for(const v of obj) walkForRefs(v,addEdge); return; }
      for(const [k,v] of Object.entries(obj)){
        // FHIR Reference element can be string in 'reference'
        if(k==="reference" && typeof v==="string"){
          const r = normRef(v);
          if(r) addEdge(r);
        } else if(v && typeof v==="object"){
          walkForRefs(v,addEdge);
        }
      }
    }

    function labelFor(nid){
      // Compact label: keep type and tail
      if(nid.startsWith("urn:uuid:")) return nid;
      if(nid.includes("?")) return nid; // logical reference
      return nid; // Resource/id already
    }

    function groupFor(nid){
      if(nid.startsWith("urn:uuid:")) return "URN";
      if(nid.includes("?")) return (nid.split("?")[0]||"Ref").split("/")[0]||"Ref";
      if(nid.includes("/")) return nid.split("/")[0]||"Ref";
      return "Ref";
    }

    // Build graph from a Bundle object
    function buildGraph(bundle){
      const nodes = new vis.DataSet();
      const edges = new vis.DataSet();
      const seenNode = new Set();
      const seenEdge = new Set();

      const resourceMap = Object.create(null);   // nid -> resource
      const fullUrlMap  = Object.create(null);   // entry.fullUrl -> nid
      const canonIdMap  = Object.create(null);   // "Resource/id" -> nid

      const entries = bundle?.entry || [];

      // First pass: add nodes that exist in the bundle and populate maps
      for(const e of entries){
        const r  = e.resource || {};
        const rt = r.resourceType || "Unknown";
        // Either resource.id or the tail of fullUrl; keep full urn as tail (for mapping)
        const rid = (r.id && String(r.id)) || (e.fullUrl ? String(e.fullUrl) : "");
        if(!rid){ continue; }

        const nid = nodeId(rt, rid);
        if(!seenNode.has(nid)){
          seenNode.add(nid);
          nodes.add({ id:nid, label:labelFor(nid), shape:"box", group:rt });
        }
        // Save resource under its node id
        resourceMap[nid] = r;

        // Map the entry.fullUrl to nid (for urn:uuid)
        if(e.fullUrl) { fullUrlMap[String(e.fullUrl)] = nid; }

        // If the resource actually has a canonical id (not a full urn), map Resource/id -> nid
        if(r.id && /^[^:\/\s]+$/.test(String(r.id))){
          const can = rt + "/" + String(r.id);
          canonIdMap[can] = nid;
        }
      }

      // Second pass: walk references and add edges (and placeholder nodes)
      for(const e of entries){
        const r  = e.resource || {};
        const rt = r.resourceType || "Unknown";
        const rid = (r.id && String(r.id)) || (e.fullUrl ? String(e.fullUrl) : "");
        if(!rid) continue;

        const from = nodeId(rt, rid);

        walkForRefs(r, (rawTarget)=>{
          let to = rawTarget; // normalized string from normRef

          // Try to resolve urn:uuid to actual nid
          if(to.startsWith("urn:uuid:") && fullUrlMap[to]){
            to = fullUrlMap[to]; // resolved nid like "Type/urn:uuid:..."
          }
          // Try to resolve Resource/id to nid if we have it
          if(!to.startsWith("urn:uuid:") && !to.includes("?") && canonIdMap[to]){
            to = canonIdMap[to]; // ensure matches existing node id shape
          }

          // Ensure target node exists (placeholder if not in bundle)
          if(!seenNode.has(to)){
            seenNode.add(to);
            // If we don't have the resource in resourceMap, mark as Missing (gray)
            const isMissing = !resourceMap[to];
            nodes.add({
                id: to,
                label: labelFor(to),
                shape: "ellipse",
                group: isMissing ? "Missing" : groupFor(to)
            });
          }


          const key = from + "->" + to;
          if(!seenEdge.has(key)){
            seenEdge.add(key);
            edges.add({ from, to, arrows:"to", smooth:{type:"dynamic"} });
          }
        });
      }

      // Network/UI
      const container = el("graph");
      const network = new vis.Network(container, {nodes,edges}, {
        physics:{enabled:true,solver:"barnesHut", barnesHut:{springLength:250}},
        interaction:{hover:true,tooltipDelay:120},
        edges:{color:{inherit:false}},
        groups:{
            Missing:{ // nodes not in the bundle (only referenced)
            color: { background: "#e0e0e0", border: "#9e9e9e", highlight: { background: "#e0e0e0", border: "#616161" }},
            font: { color: "#616161" },
            shape: "ellipse"
            }
        }
      });



      // Selection → dump resource JSON if present
      network.on("selectNode",(params)=>{
        const nid = params.nodes[0];
        const r = resourceMap[nid];
        if(r){
          el("detail").innerHTML = "<pre>"+JSON.stringify(r,null,2)+"</pre>";
          console.log("Selected:", nid, r);
        } else {
          el("detail").innerHTML = "<pre class='muted'>Keine Ressource im Bundle zu diesem Knoten gefunden.\n"+nid+"</pre>";
          console.log("Selected (no resource in bundle):", nid);
        }
      });

      el("counts").textContent = `${nodes.length} Knoten · ${edges.length} Kanten`;
      el("fit").onclick = ()=>network.fit({animation:{duration:300}});
      const phys = el("physics");
      phys.onchange = ()=>network.setOptions({physics:{enabled:phys.checked}});

      return {nodes,edges};
    }

    // ——— Source loaders ———
    async function loadFromServer(){
      msg(""); log(`Quelle: ${proxy}`);
      const res = await fetch(proxy,{cache:"no-store"});
      if(!res.ok) throw new Error("HTTP "+res.status);
      return res.json();
    }

    function loadFromTextarea(){
      const txt = el("bundleText").value.trim();
      if(!txt) throw new Error("Kein JSON im Textfeld.");
      try { return JSON.parse(txt); }
      catch(err){ throw new Error("Ungültiges JSON: "+(err?.message||err)); }
    }

    function loadFromFile(file){
      return new Promise((resolve,reject)=>{
        const r = new FileReader();
        r.onload = ()=> {
          try{ resolve(JSON.parse(String(r.result||""))); }
          catch(err){ reject(new Error("Ungültiges JSON in Datei: "+(err?.message||err))); }
        };
        r.onerror = ()=>reject(new Error("Datei konnte nicht gelesen werden."));
        r.readAsText(file,"utf-8");
      });
    }

    // ——— Wire UI ———
    function renderBundle(bundle){
      try{
        buildGraph(bundle);
        msg("");
      }catch(err){
        msg(err?.message||String(err));
        console.error(err);
      }
    }

    el("btnFetch").onclick = async ()=>{
      try{ msg("Lade…"); const b = await loadFromServer(); renderBundle(b); }
      catch(err){ msg(err?.message||String(err)); console.error(err); }
    };

    el("btnUseText").onclick = ()=>{
      try{ const b = loadFromTextarea(); log("Quelle: eingegebener Text"); renderBundle(b); }
      catch(err){ msg(err?.message||String(err)); console.error(err); }
    };

    el("filePick").addEventListener("change", async (e)=>{
      const f = e.target.files?.[0];
      if(!f) return;
      try{ msg("Lade Datei…"); const b = await loadFromFile(f); log(`Quelle: Datei ${f.name}`); renderBundle(b); }
      catch(err){ msg(err?.message||String(err)); console.error(err); }
      finally{ msg(""); }
    });

    // Auto-fetch once (keeps your original behavior), but user may paste/upload afterward.
    (async()=>{
      try{
        const b = await loadFromServer();
        renderBundle(b);
      }catch(err){
        msg("Fehler beim Laden vom Server: "+(err?.message||err));
        console.error(err);
      }
    })();

  })();
  </script>
  #(##class(HS.Local.Demo.FHIR.Utils).Footer())#
  </body></html>>
  Quit $$$OK
}

}
