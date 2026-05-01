#!/usr/bin/env python3
"""
Graphify semantic extraction using Claude (Anthropic) backend.
Processes uncached files, merges with existing AST data, then builds
the final clustered graph, GRAPH_REPORT.md, and graph.html.
"""
import sys, json, os, time
from pathlib import Path

# ── path setup ──────────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).parent
GRAPHIFY_SITE = Path("/Users/sr20536224wipro.com/.local/share/uv/tools/graphifyy/lib/python3.14/site-packages")
sys.path.insert(0, str(GRAPHIFY_SITE))

# ── verify env ───────────────────────────────────────────────────────────────
api_key = os.environ.get("ANTHROPIC_API_KEY", "")
if not api_key:
    print("ERROR: ANTHROPIC_API_KEY is not set.", file=sys.stderr)
    sys.exit(1)

# Use claude-haiku for fast, cheap extraction
MODEL = "claude-haiku-4-5-20251001"
CHUNK_SIZE = 20
OUT = REPO_ROOT / "graphify-out"

# ── imports ──────────────────────────────────────────────────────────────────
import anthropic
from graphify.cache import check_semantic_cache, save_semantic_cache
from graphify.build import build_from_json
from graphify.cluster import cluster, score_all
from graphify.analyze import god_nodes, surprising_connections, suggest_questions
from graphify.report import generate
from graphify.export import to_json, to_html
from graphify.detect import save_manifest
from networkx.readwrite import json_graph

# ── constants ─────────────────────────────────────────────────────────────────
EXTRACTION_SYSTEM = """\
You are a graphify semantic extraction agent. Extract a knowledge graph fragment from the files provided.
Output ONLY valid JSON — no explanation, no markdown fences, no preamble.

Rules:
- EXTRACTED: relationship explicit in source (import, call, citation, reference)
- INFERRED: reasonable inference (shared data structure, implied dependency)
- AMBIGUOUS: uncertain — flag for review, do not omit

Node ID format: lowercase, only [a-z0-9_], no dots or slashes.
Format: {stem}_{entity} where stem = filename without extension, entity = symbol name (both normalised).

confidence_score is REQUIRED on every edge:
- EXTRACTED edges: 1.0
- INFERRED edges: 0.6-0.9
- AMBIGUOUS edges: 0.1-0.3

Output exactly this schema (no other text):
{"nodes":[{"id":"stem_entity","label":"Human Readable Name","file_type":"code|document|paper|image|concept","source_file":"relative/path","source_location":null,"source_url":null,"captured_at":null,"author":null,"contributor":null}],"edges":[{"source":"node_id","target":"node_id","relation":"calls|implements|references|cites|conceptually_related_to|shares_data_with|semantically_similar_to","confidence":"EXTRACTED|INFERRED|AMBIGUOUS","confidence_score":1.0,"source_file":"relative/path","source_location":null,"weight":1.0}],"hyperedges":[],"input_tokens":0,"output_tokens":0}
"""


def read_files(paths: list[Path], root: Path) -> str:
    parts = []
    for p in paths:
        try:
            rel = p.relative_to(root)
        except ValueError:
            rel = p
        try:
            content = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        parts.append(f"=== {rel} ===\n{content[:15000]}")
    return "\n\n".join(parts)


def parse_llm_json(raw: str) -> dict:
    if raw.startswith("```"):
        raw = raw.split("```", 2)[1]
        if raw.startswith("json"):
            raw = raw[4:]
        raw = raw.rsplit("```", 1)[0]
    try:
        return json.loads(raw.strip())
    except json.JSONDecodeError as e:
        print(f"  [WARN] LLM returned invalid JSON, skipping: {e}", file=sys.stderr)
        return {"nodes": [], "edges": [], "hyperedges": [], "input_tokens": 0, "output_tokens": 0}


def call_claude(user_msg: str) -> dict:
    client = anthropic.Anthropic(api_key=api_key)
    resp = client.messages.create(
        model=MODEL,
        max_tokens=4096,
        system=EXTRACTION_SYSTEM,
        messages=[{"role": "user", "content": user_msg}],
    )
    result = parse_llm_json(resp.content[0].text if resp.content else "{}")
    result["input_tokens"] = resp.usage.input_tokens if resp.usage else 0
    result["output_tokens"] = resp.usage.output_tokens if resp.usage else 0
    return result


def extract_corpus(files: list[Path], root: Path, chunk_size: int = CHUNK_SIZE) -> dict:
    chunks = [files[i:i + chunk_size] for i in range(0, len(files), chunk_size)]
    merged = {"nodes": [], "edges": [], "hyperedges": [], "input_tokens": 0, "output_tokens": 0}
    total = len(chunks)

    for idx, chunk in enumerate(chunks):
        t0 = time.time()
        print(f"  Chunk {idx+1}/{total}: {len(chunk)} files ... ", end="", flush=True)
        try:
            user_msg = read_files(chunk, root)
            if not user_msg.strip():
                print("skipped (empty)")
                continue
            result = call_claude(user_msg)
            elapsed = round(time.time() - t0, 1)
            n_nodes = len(result.get("nodes", []))
            n_edges = len(result.get("edges", []))
            print(f"{n_nodes} nodes, {n_edges} edges ({result.get('input_tokens', 0):,} tok in, {elapsed}s)")
            merged["nodes"].extend(result.get("nodes", []))
            merged["edges"].extend(result.get("edges", []))
            merged["hyperedges"].extend(result.get("hyperedges", []))
            merged["input_tokens"] += result.get("input_tokens", 0)
            merged["output_tokens"] += result.get("output_tokens", 0)
        except Exception as e:
            print(f"FAILED: {e}", file=sys.stderr)
            continue

    return merged


def main():
    os.chdir(REPO_ROOT)
    print(f"\n{'='*60}")
    print(f"  Graphify Semantic Extraction — {MODEL}")
    print(f"{'='*60}\n")

    # ── Step 1: Load detection manifest ──────────────────────────────────────
    detect_path = OUT / ".graphify_detect.json"
    if not detect_path.exists():
        print("ERROR: .graphify_detect.json not found. Run detection first.", file=sys.stderr)
        sys.exit(1)
    detect = json.loads(detect_path.read_text())
    all_files_by_type = detect.get("files", {})
    doc_files = [Path(f) for f in all_files_by_type.get("document", [])]
    img_files = [Path(f) for f in all_files_by_type.get("image", [])]
    code_files = [Path(f) for f in all_files_by_type.get("code", [])]

    print(f"Corpus: {detect.get('total_files', 0)} files, {detect.get('total_words', 0):,} words")
    print(f"  code:     {len(code_files)} files (AST-extracted, in graph.json)")
    print(f"  document: {len(doc_files)} files")
    print(f"  image:    {len(img_files)} files")

    # SVGs are text-readable; treat as documents
    all_semantic_files = doc_files + img_files
    print(f"  → semantic extraction target: {len(all_semantic_files)} files\n")

    # ── Step 2: Check semantic cache ─────────────────────────────────────────
    print("Checking semantic cache ... ", end="", flush=True)
    file_strs = [str(f) for f in all_semantic_files]
    cached_nodes, cached_edges, cached_hyperedges, uncached_strs = check_semantic_cache(file_strs)
    uncached = [Path(f) for f in uncached_strs]
    cached_hit = len(all_semantic_files) - len(uncached)
    print(f"{cached_hit} cached, {len(uncached)} to extract\n")

    new_semantic = {"nodes": [], "edges": [], "hyperedges": [], "input_tokens": 0, "output_tokens": 0}

    # ── Step 3: Extract uncached files ───────────────────────────────────────
    if uncached:
        n_chunks = (len(uncached) + CHUNK_SIZE - 1) // CHUNK_SIZE
        est_secs = n_chunks * 8  # ~8s/chunk with haiku
        print(f"Semantic extraction: {len(uncached)} files → {n_chunks} chunks (est ~{est_secs}s)\n")

        new_semantic = extract_corpus(uncached, REPO_ROOT)
        print(f"\nExtraction complete: {len(new_semantic['nodes'])} nodes, {len(new_semantic['edges'])} edges")
        print(f"  Tokens: {new_semantic['input_tokens']:,} in / {new_semantic['output_tokens']:,} out\n")

        # Save new results to cache
        print("Saving to semantic cache ... ", end="", flush=True)
        saved = save_semantic_cache(new_semantic["nodes"], new_semantic["edges"], new_semantic.get("hyperedges", []))
        print(f"{saved} files cached\n")

    else:
        print("All files already cached — skipping extraction.\n")

    # ── Step 4: Merge cached + new semantic ───────────────────────────────────
    all_sem_nodes = cached_nodes + new_semantic["nodes"]
    all_sem_edges = cached_edges + new_semantic["edges"]
    all_sem_hyperedges = cached_hyperedges + new_semantic.get("hyperedges", [])

    # Deduplicate nodes by id
    seen_ids = set()
    deduped_sem_nodes = []
    for n in all_sem_nodes:
        if n["id"] not in seen_ids:
            seen_ids.add(n["id"])
            deduped_sem_nodes.append(n)

    total_in = new_semantic["input_tokens"]
    total_out = new_semantic["output_tokens"]

    # ── Step 5: Load existing AST nodes from graph.json ──────────────────────
    graph_path = OUT / "graph.json"
    if graph_path.exists():
        print("Loading AST nodes from existing graph.json ... ", end="", flush=True)
        graph_data = json.loads(graph_path.read_text())
        # graph.json is in node_link format
        G_existing = json_graph.node_link_graph(graph_data, edges="links")
        ast_nodes = [{"id": n, **d} for n, d in G_existing.nodes(data=True)]
        ast_edges = [{"source": u, "target": v, **d} for u, v, d in G_existing.edges(data=True)]
        print(f"{len(ast_nodes)} AST nodes, {len(ast_edges)} AST edges\n")
    else:
        print("No existing graph.json — starting fresh\n")
        ast_nodes, ast_edges = [], []

    # ── Step 6: Merge AST + semantic ─────────────────────────────────────────
    seen_ast_ids = {n["id"] for n in ast_nodes}
    merged_nodes = list(ast_nodes)
    for n in deduped_sem_nodes:
        if n["id"] not in seen_ast_ids:
            merged_nodes.append(n)
            seen_ast_ids.add(n["id"])

    merged_edges = ast_edges + all_sem_edges
    merged = {
        "nodes": merged_nodes,
        "edges": merged_edges,
        "hyperedges": all_sem_hyperedges,
        "input_tokens": total_in,
        "output_tokens": total_out,
    }

    extract_path = OUT / ".graphify_extract.json"
    extract_path.write_text(json.dumps(merged, indent=2))
    print(f"Merged: {len(merged_nodes)} nodes ({len(ast_nodes)} AST + {len(deduped_sem_nodes)} semantic), "
          f"{len(merged_edges)} edges\n")

    # ── Step 7: Build graph + cluster ────────────────────────────────────────
    print("Building graph and clustering ... ", end="", flush=True)
    G = build_from_json(merged)
    if G.number_of_nodes() == 0:
        print("\nERROR: Graph is empty after extraction!", file=sys.stderr)
        sys.exit(1)

    communities = cluster(G)
    cohesion = score_all(G, communities)
    tokens = {"input": total_in, "output": total_out}
    gods = god_nodes(G)
    surprises = surprising_connections(G, communities)
    print(f"{G.number_of_nodes()} nodes, {G.number_of_edges()} edges, {len(communities)} communities\n")

    # ── Step 8: Auto-label communities ───────────────────────────────────────
    # Build labels by inspecting top-degree nodes in each community
    import networkx as nx
    labels: dict[int, str] = {}
    for cid, members in communities.items():
        top = sorted(members, key=lambda n: G.degree(n), reverse=True)[:5]
        top_labels = [G.nodes[n].get("label", n) for n in top if n in G.nodes]
        # Simple heuristic: join first two words of top label
        label = top_labels[0] if top_labels else f"Community {cid}"
        labels[cid] = label[:40]

    questions = suggest_questions(G, communities, labels)

    # ── Step 9: Generate GRAPH_REPORT.md ─────────────────────────────────────
    print("Generating GRAPH_REPORT.md ... ", end="", flush=True)
    report = generate(G, communities, cohesion, labels, gods, surprises,
                      detect, tokens, str(REPO_ROOT), suggested_questions=questions)
    (OUT / "GRAPH_REPORT.md").write_text(report)
    print("done\n")

    # Save analysis for HTML step
    analysis = {
        "communities": {str(k): v for k, v in communities.items()},
        "cohesion": {str(k): v for k, v in cohesion.items()},
        "gods": gods,
        "surprises": surprises,
        "questions": questions,
    }
    (OUT / ".graphify_analysis.json").write_text(json.dumps(analysis, indent=2))
    (OUT / ".graphify_labels.json").write_text(json.dumps({str(k): v for k, v in labels.items()}))

    # ── Step 10: Export graph.json ────────────────────────────────────────────
    print("Exporting graph.json ... ", end="", flush=True)
    to_json(G, communities, str(OUT / "graph.json"))
    print("done\n")

    # ── Step 11: Generate graph.html ─────────────────────────────────────────
    print("Generating graph.html ... ", end="", flush=True)
    try:
        to_html(G, communities, str(OUT / "graph.html"), community_labels=labels or None)
        print("done\n")
    except Exception as e:
        print(f"WARNING: HTML generation failed: {e}\n", file=sys.stderr)

    # ── Step 12: Update manifest + cost tracker ───────────────────────────────
    print("Saving manifest and cost tracker ... ", end="", flush=True)
    save_manifest(detect["files"])

    from datetime import datetime, timezone
    cost_path = OUT / "cost.json"
    cost = json.loads(cost_path.read_text()) if cost_path.exists() else \
           {"runs": [], "total_input_tokens": 0, "total_output_tokens": 0}
    cost["runs"].append({
        "date": datetime.now(timezone.utc).isoformat(),
        "input_tokens": total_in,
        "output_tokens": total_out,
        "files": detect.get("total_files", 0),
        "backend": f"anthropic/{MODEL}",
    })
    cost["total_input_tokens"] += total_in
    cost["total_output_tokens"] += total_out
    cost_path.write_text(json.dumps(cost, indent=2))
    print("done\n")

    # ── Step 13: Cleanup temp files ───────────────────────────────────────────
    for tmp in [".graphify_extract.json", ".graphify_analysis.json",
                ".graphify_detect.json"]:
        tmp_path = OUT / tmp
        if tmp_path.exists():
            tmp_path.unlink()

    # ── Final summary ─────────────────────────────────────────────────────────
    print(f"{'='*60}")
    print(f"  Graph complete. Outputs in: {OUT}/")
    print(f"{'='*60}")
    print(f"  graph.html       – interactive graph (open in browser)")
    print(f"  GRAPH_REPORT.md  – audit report")
    print(f"  graph.json       – raw graph data")
    print(f"\n  Nodes:       {G.number_of_nodes()}")
    print(f"  Edges:       {G.number_of_edges()}")
    print(f"  Communities: {len(communities)}")
    print(f"  Tokens:      {total_in:,} in / {total_out:,} out")

    # Print key sections from the report
    report_lines = report.split("\n")
    in_section = False
    sections_found = 0
    for line in report_lines:
        if any(line.startswith(f"## {s}") for s in ["God Nodes", "Surprising Connections", "Suggested Questions"]):
            in_section = True
            sections_found += 1
            print()
        if in_section:
            print(line)
        if in_section and line.strip() == "" and sections_found > 0:
            # Keep printing until next ## section or end
            pass
        if in_section and line.startswith("## ") and not any(
            line.startswith(f"## {s}") for s in ["God Nodes", "Surprising Connections", "Suggested Questions"]
        ):
            in_section = False

    print("\nMost interesting question: graph ready to explore with `graphify query`")


if __name__ == "__main__":
    main()
