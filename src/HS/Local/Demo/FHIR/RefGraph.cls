Class HS.Local.Demo.FHIR.RefGraph Extends %CSP.Page
{

ClassMethod OnPage() As %Status
{
  &html<<!doctype html><html><head><meta charset="utf-8">
  <title>FHIR Reference Graph</title>
  <script src="https://unpkg.com/vis-network@9.1.6/dist/vis-network.min.js"></script>
  <link rel="stylesheet" href="https://unpkg.com/vis-network@9.1.6/styles/vis-network.min.css"/>
  <style>
    body{font-family:system-ui,Segoe UI,Arial;margin:0}
    header{padding:12px 16px;border-bottom:1px solid #eee}
    #hint{color:#666;font-size:13px}
    #controls{padding:8px 16px;border-bottom:1px solid #eee;display:flex;gap:12px;align-items:center}
    #graph{height:70vh}
    #log{padding:8px 16px;color:#666;font-size:12px}
    .badge{display:inline-block;padding:2px 6px;border-radius:999px;border:1px solid #ccc;background:#fafafa;font-size:12px}
  </style>
  </head><body>
  <header>
    <h2 style="margin:0">FHIR Reference Graph</h2>
    <div id="hint">Die Parameter in der URL werden an <code>Demo.FHIR.Utils.cls</code> weitergereicht.
      Beispiel: <span class="badge">?id=3</span></div>
  </header>
  <div id="controls">
    <button id="fit">Fit</button>
    <label><input type="checkbox" id="physics" checked> Physics</label>
    <span id="counts" class="badge">0 Knoten · 0 Kanten</span>
    <span id="msg" style="color:#b00020"></span>
  </div>
  <div id="graph"></div>
  <div id="log"></div>
  
  <script type="text/javascript">
    (async ()=>{
    const id = #($get(%request.Data("id",1),2))#;
    const qs = "?p=Patient/"+id+"/$everything";
    const proxy = "HS.Local.Demo.FHIR.Utils.cls" + qs;

    const msg = (t)=>{ const el=document.getElementById("msg"); el.textContent=t||""; };
    const log = (t)=>{ document.getElementById("log").textContent=t||""; };

    function normRef(s){
        if(!s || s.startsWith("#")) return null;
        try{
        const parts=s.split("/");
        const i=parts.findIndex(x=>/^[A-Za-z]+$/.test(x));
        if(i>=0 && parts[i+1]) return parts[i]+"/"+parts[i+1].split("?")[0].split("#")[0];
        }catch(e){}
        return s.includes("/") ? s.split("?")[0].split("#")[0] : null;
    }

    function nodeId(rt,id){ return rt+"/"+id; }

    function walkForRefs(obj, addEdge){
        if(!obj || typeof obj!=="object") return;
        if(Array.isArray(obj)){ for(const v of obj) walkForRefs(v,addEdge); return; }
        for(const [k,v] of Object.entries(obj)){
        if(k==="reference" && typeof v==="string"){
            const ref=normRef(v);
            if(ref) addEdge(ref);
        } else if(v && typeof v==="object"){
            walkForRefs(v,addEdge);
        }
        }
    }

    try{
        const res = await fetch(proxy,{cache:"no-store"});
        if(!res.ok) throw new Error("HTTP "+res.status);
        const bundle = await res.json();

        const nodes=new vis.DataSet();
        const edges=new vis.DataSet();
        const seenNode=new Set();
        const seenEdge=new Set();
        const resourceMap = {};  // store resources keyed by ResourceType/id

        const entries=bundle.entry||[];
        for(const e of entries){
        const r=e.resource||{};
        const rt=r.resourceType||"Unknown";
        const rid=r.id||(e.fullUrl?(e.fullUrl.split("/").pop()||""):"");
        const nid=rid?nodeId(rt,rid):null;
        if(nid){
            resourceMap[nid]=r;  // remember full resource
            if(!seenNode.has(nid)){
            seenNode.add(nid);
            nodes.add({id:nid,label:nid,shape:"box",group:rt});
            }
        }
        }

        for(const e of entries){
        const r=e.resource||{};
        const rt=r.resourceType||"Unknown";
        const rid=r.id||(e.fullUrl?(e.fullUrl.split("/").pop()||""):"");
        const from=rid?nodeId(rt,rid):null;
        if(!from) continue;
        walkForRefs(r,(targetRef)=>{
            const to=targetRef;
            if(!to) return;
            if(!seenNode.has(to)){
            seenNode.add(to);
            nodes.add({id:to,label:to,shape:"ellipse",group:to.split("/")[0]||"Ref"});
            }
            const key=from+"->"+to;
            if(!seenEdge.has(key)){
            seenEdge.add(key);
            edges.add({from,to,arrows:"to",smooth:{type:"dynamic"}});
            }
        });
        }

        const container=document.getElementById("graph");
        const network=new vis.Network(container,{nodes,edges},{
        physics:{enabled:true,solver:"barnesHut"},
        interaction:{hover:true,tooltipDelay:120},
        edges:{color:{inherit:false}}
        });

        // --- Selection handler ---
        network.on("selectNode",(params)=>{
        const nid=params.nodes[0];
        const r=resourceMap[nid];
        if(r){
            console.clear();
            console.log("Selected:", nid, r);
        } else {
            console.log("Selected (no resource in bundle):", nid);
        }
        });

        document.getElementById("counts").textContent=`${nodes.length} Knoten · ${edges.length} Kanten`;
        document.getElementById("fit").onclick=()=>network.fit({animation:{duration:300}});
        const phys=document.getElementById("physics");
        phys.onchange=()=>network.setOptions({physics:{enabled:phys.checked}});

        log(`Quelle: ${proxy}`);
        if(nodes.length===0) msg("Keine Ressourcen im Bundle.");
    }catch(e){
        msg("Fehler: "+(e?.message||e));
        console.error(e);
    }
    })();
    </script>
  </body></html>>
  Quit $$$OK
}

}
