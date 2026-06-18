import { useState, useEffect, useMemo } from "react";
import { supabase, AGENCY_ID } from "../lib/supabase.js";

// ============================================================
// BCC PERSISTENT MEMORY MODULE v1.0
// Business Command Center — State Farm Agent Edition
// Built by Imaginary Farms LLC · imaginary-farms.com
//
// Reads/writes the public.persistent_memory table for this
// agency. Every active entry is passed to Claude as context
// at the start of each conversation. This is Claude's brain
// about the agency: profile, business context, goals, key
// contacts, compliance notes, and standing operational facts.
//
// SCHEMA: id, agency_id, category, title, content, source,
//         is_active, added_by, created_at, updated_at
// ============================================================

const T = {
  navy: "#1B2B4B", blue: "#2D7DD2", blueLt: "#EFF6FF",
  green: "#10B981", greenLt: "#D1FAE5",
  amber: "#F59E0B", amberLt: "#FEF3C7",
  red: "#EF4444", redLt: "#FEE2E2",
  slate50: "#F8FAFC", slate100: "#F1F5F9", slate200: "#E2E8F0",
  slate400: "#94A3B8", slate500: "#64748B", slate600: "#475569",
  slate700: "#334155", slate800: "#1E293B", slate900: "#0F172A",
  white: "#FFFFFF",
};

// Suggested categories for new entries — matches the model in
// the userPreferences spec. The actual category set displayed
// is whatever shows up in the data; this list just powers the
// Add Memory dropdown so the agent isn't typing free-form.
const CATEGORY_SUGGESTIONS = [
  "agency_profile",
  "business_context",
  "financial_context",
  "sf_compensation",
  "accounting_rules",
  "compliance_rules",
  "communication_prefs",
  "goals",
  "key_contacts",
];

// Friendly display labels — fall back to the raw category name
// for anything not mapped (so the UI never loses an entry).
const CATEGORY_LABELS = {
  agency_profile:      "🏢  Agency Profile",
  business_context:    "💼  Business Context",
  financial_context:   "💰  Financial Context",
  sf_compensation:     "📊  SF Compensation",
  accounting_rules:    "📒  Accounting Rules",
  compliance_rules:    "🛡️  Compliance Rules",
  communication_prefs: "💬  Communication Prefs",
  goals:               "🎯  Goals & Priorities",
  key_contacts:        "🤝  Key Contacts",
  automation:          "⚡  Automation",
  convention:          "🧭  Convention",
  data_flow:           "🔁  Data Flow",
  session_note:        "📝  Session Notes",
  system:              "🛠️  System Facts",
};
const labelFor = (cat) => CATEGORY_LABELS[cat] || `📌  ${cat || "uncategorized"}`;

// ─── Reusable bits ────────────────────────────────────────────
const Card = ({ children, style = {} }) => (
  <div style={{ background: T.white, border: `1px solid ${T.slate200}`, borderRadius: 12, padding: 18, ...style }}>{children}</div>
);

const Btn = ({ kind = "secondary", onClick, disabled, children, style = {} }) => {
  const styles = {
    primary:   { background: T.navy,    color: T.white,    border: "none" },
    secondary: { background: T.white,   color: T.slate700, border: `1px solid ${T.slate200}` },
    danger:    { background: T.white,   color: T.red,      border: `1px solid ${T.redLt}` },
    accent:    { background: T.blueLt,  color: T.blue,     border: `1px solid ${T.blueLt}` },
  };
  return (
    <button onClick={onClick} disabled={disabled} style={{
      padding: "7px 12px", fontSize: 11, fontWeight: 600, borderRadius: 7,
      cursor: disabled ? "not-allowed" : "pointer", opacity: disabled ? 0.5 : 1,
      transition: "all 0.12s", whiteSpace: "nowrap", ...styles[kind], ...style,
    }}>{children}</button>
  );
};

const AskBtn = ({ context }) => (
  <Btn kind="accent" onClick={() => {
    if (navigator.clipboard?.writeText) navigator.clipboard.writeText(context || "");
    window.open("https://claude.ai/new", "_blank", "noopener");
  }}>⚡ Ask Claude</Btn>
);

// ─── Add / Edit Modal ─────────────────────────────────────────
const MemoryModal = ({ initial, onSave, onCancel }) => {
  const startCat = initial?.category && !CATEGORY_SUGGESTIONS.includes(initial.category) ? "" : (initial?.category || CATEGORY_SUGGESTIONS[0]);
  const [form, setForm] = useState({
    category: startCat,
    title:    initial?.title    || "",
    content:  initial?.content  || "",
    source:   initial?.source   || "claude_conversation",
  });
  const [customCat, setCustomCat] = useState(initial?.category && !CATEGORY_SUGGESTIONS.includes(initial.category) ? initial.category : "");
  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));
  const isEdit = Boolean(initial?.id);
  const finalCategory = (customCat.trim() || form.category || "").trim();
  const valid = finalCategory && form.content.trim();

  return (
    <div style={{ position: "fixed", inset: 0, background: "rgba(15,23,42,0.5)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 1000, padding: 20 }}>
      <div style={{ background: T.white, borderRadius: 14, width: "100%", maxWidth: 560, padding: 22, maxHeight: "90vh", overflow: "auto" }}>
        <div style={{ fontSize: 16, fontWeight: 700, color: T.slate900, marginBottom: 4 }}>{isEdit ? "Edit memory" : "Add memory"}</div>
        <div style={{ fontSize: 11, color: T.slate500, marginBottom: 18 }}>Stored in <code style={{ background: T.slate100, padding: "1px 5px", borderRadius: 4 }}>persistent_memory</code>. Claude reads every active entry here at the start of each conversation.</div>

        <div style={{ marginBottom: 12 }}>
          <div style={{ fontSize: 11, fontWeight: 600, color: T.slate700, marginBottom: 5 }}>Category</div>
          <select value={form.category} onChange={e => { set("category", e.target.value); setCustomCat(""); }}
            style={{ width: "100%", padding: "8px 10px", fontSize: 12, color: T.slate800, border: `1px solid ${T.slate200}`, borderRadius: 7, background: T.white, marginBottom: 6 }}>
            {CATEGORY_SUGGESTIONS.map(c => <option key={c} value={c}>{labelFor(c)}</option>)}
          </select>
          <input placeholder="…or enter a custom category" value={customCat} onChange={e => setCustomCat(e.target.value)}
            style={{ width: "100%", padding: "7px 10px", fontSize: 11, color: T.slate700, border: `1px solid ${T.slate200}`, borderRadius: 7 }} />
        </div>

        <div style={{ marginBottom: 12 }}>
          <div style={{ fontSize: 11, fontWeight: 600, color: T.slate700, marginBottom: 5 }}>Title <span style={{ fontWeight: 400, color: T.slate400 }}>· short label, optional</span></div>
          <input value={form.title} onChange={e => set("title", e.target.value)}
            style={{ width: "100%", padding: "8px 10px", fontSize: 12, color: T.slate800, border: `1px solid ${T.slate200}`, borderRadius: 7 }} />
        </div>

        <div style={{ marginBottom: 12 }}>
          <div style={{ fontSize: 11, fontWeight: 600, color: T.slate700, marginBottom: 5 }}>Content</div>
          <textarea value={form.content} onChange={e => set("content", e.target.value)} rows={6}
            placeholder="What should Claude know? Be specific. The more accurate this is, the more useful Claude becomes."
            style={{ width: "100%", padding: "9px 11px", fontSize: 12, color: T.slate800, border: `1px solid ${T.slate200}`, borderRadius: 7, fontFamily: "inherit", lineHeight: 1.5, resize: "vertical" }} />
        </div>

        <div style={{ marginBottom: 18 }}>
          <div style={{ fontSize: 11, fontWeight: 600, color: T.slate700, marginBottom: 5 }}>Source <span style={{ fontWeight: 400, color: T.slate400 }}>· optional</span></div>
          <input value={form.source} onChange={e => set("source", e.target.value)}
            placeholder="e.g. claude_conversation, intake_form, install_seed"
            style={{ width: "100%", padding: "8px 10px", fontSize: 11, color: T.slate600, border: `1px solid ${T.slate200}`, borderRadius: 7 }} />
        </div>

        <div style={{ display: "flex", justifyContent: "flex-end", gap: 8 }}>
          <Btn kind="secondary" onClick={onCancel}>Cancel</Btn>
          <Btn kind="primary" disabled={!valid} onClick={() => onSave({ ...form, category: finalCategory })}>{isEdit ? "Save" : "Add memory"}</Btn>
        </div>
      </div>
    </div>
  );
};

// ─── Memory Card ──────────────────────────────────────────────
const MemoryCard = ({ entry, onEdit, onDelete }) => {
  const [expanded, setExpanded] = useState(false);
  const content = entry.content || "";
  const lines = content.split("\n");
  const longContent = lines.length > 4 || content.length > 320;
  const display = expanded || !longContent ? content : lines.slice(0, 4).join("\n");
  const askContext = `Memory entry from category "${entry.category}" titled "${entry.title || "(untitled)"}":\n\n${content}\n\nHelp me think about this.`;

  return (
    <Card style={{ borderLeft: `3px solid ${T.blue}`, marginBottom: 10 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 12, marginBottom: 8, flexWrap: "wrap" }}>
        <div style={{ flex: 1, minWidth: 200 }}>
          <div style={{ fontSize: 13, fontWeight: 700, color: T.slate900 }}>{entry.title || "(untitled)"}</div>
          <div style={{ fontSize: 10, color: T.slate400, marginTop: 2 }}>
            Added by {entry.added_by || "system"}{entry.source ? ` · ${entry.source}` : ""}{entry.updated_at ? ` · updated ${new Date(entry.updated_at).toLocaleDateString()}` : ""}
          </div>
        </div>
        <div style={{ display: "flex", gap: 6, flexShrink: 0 }}>
          <AskBtn context={askContext} />
          <Btn kind="secondary" onClick={() => onEdit(entry)}>Edit</Btn>
          <Btn kind="danger" onClick={() => onDelete(entry)}>Delete</Btn>
        </div>
      </div>
      <div style={{ fontSize: 12, color: T.slate700, lineHeight: 1.65, whiteSpace: "pre-wrap" }}>{display}</div>
      {longContent && (
        <button onClick={() => setExpanded(e => !e)}
          style={{ marginTop: 6, padding: 0, fontSize: 11, color: T.blue, background: "none", border: "none", cursor: "pointer" }}>
          {expanded ? "Show less ↑" : "Show more ↓"}
        </button>
      )}
    </Card>
  );
};

// ─── Main module ──────────────────────────────────────────────
export default function PersistentMemory() {
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [activeCategory, setActiveCategory] = useState("all");
  const [modalState, setModalState] = useState({ open: false, entry: null });

  async function load() {
    if (!supabase || !AGENCY_ID) { setLoading(false); return; }
    try {
      const { data, error } = await supabase
        .from("persistent_memory")
        .select("*")
        .eq("agency_id", AGENCY_ID)
        .eq("is_active", true)
        .order("category", { ascending: true })
        .order("updated_at", { ascending: false });
      if (error) console.error("Memory load error:", error);
      setEntries(Array.isArray(data) ? data : []);
    } catch (e) {
      console.error("Memory load exception:", e);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { load(); /* eslint-disable-next-line react-hooks/exhaustive-deps */ }, []);

  // Group + filter
  const categoryCounts = useMemo(() => {
    const counts = {};
    (entries || []).forEach(e => { counts[e?.category || "uncategorized"] = (counts[e?.category || "uncategorized"] || 0) + 1; });
    return counts;
  }, [entries]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return (entries || []).filter(e => {
      if (activeCategory !== "all" && (e?.category || "uncategorized") !== activeCategory) return false;
      if (!q) return true;
      return (
        (e?.title || "").toLowerCase().includes(q) ||
        (e?.content || "").toLowerCase().includes(q) ||
        (e?.category || "").toLowerCase().includes(q) ||
        (e?.source || "").toLowerCase().includes(q)
      );
    });
  }, [entries, search, activeCategory]);

  const handleSave = async (form) => {
    if (!supabase || !AGENCY_ID) return;
    const editing = modalState.entry?.id;
    try {
      if (editing) {
        const { error } = await supabase.from("persistent_memory")
          .update({
            category: form.category,
            title:    form.title  || null,
            content:  form.content,
            source:   form.source || null,
            updated_at: new Date().toISOString(),
          })
          .eq("id", editing);
        if (error) { console.error("Memory update error:", error); alert("Could not save."); return; }
      } else {
        const { error } = await supabase.from("persistent_memory")
          .insert({
            agency_id: AGENCY_ID,
            category:  form.category,
            title:     form.title  || null,
            content:   form.content,
            source:    form.source || null,
            added_by:  "owner",
            is_active: true,
          });
        if (error) { console.error("Memory insert error:", error); alert("Could not save."); return; }
      }
      setModalState({ open: false, entry: null });
      load();
    } catch (e) {
      console.error("Memory save exception:", e);
      alert("Could not save.");
    }
  };

  const handleDelete = async (entry) => {
    if (!entry?.id || !supabase) return;
    const previewLine = entry.title || (entry.content || "").slice(0, 80);
    if (!window.confirm(`Delete this memory entry?\n\n"${previewLine}"\n\nClaude will no longer see this. This cannot be undone.`)) return;
    try {
      const { error } = await supabase.from("persistent_memory").delete().eq("id", entry.id);
      if (error) { console.error("Memory delete error:", error); alert("Could not delete."); return; }
      load();
    } catch (e) {
      console.error("Memory delete exception:", e);
    }
  };

  const totalCount = (entries || []).length;
  const visibleHeader = activeCategory === "all" ? "All Memories" : labelFor(activeCategory);

  return (
    <div>
      {/* Header */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 16, gap: 12, flexWrap: "wrap" }}>
        <div>
          <div style={{ fontSize: 20, fontWeight: 700, color: T.slate900, letterSpacing: "-0.02em" }}>Persistent Memory</div>
          <div style={{ fontSize: 12, color: T.slate500, marginTop: 3 }}>
            {totalCount} memory entr{totalCount === 1 ? "y" : "ies"} · Claude reads all of these in every conversation
          </div>
        </div>
        <div style={{ display: "flex", gap: 8 }}>
          <AskBtn context="Here's what Claude knows about my agency. Help me think about what's missing and what I should add to make Claude more useful." />
          <Btn kind="primary" onClick={() => setModalState({ open: true, entry: null })}>+ Add Memory</Btn>
        </div>
      </div>

      {/* Explainer */}
      <Card style={{ borderLeft: `3px solid ${T.blue}`, background: T.blueLt, marginBottom: 16, borderColor: T.blueLt }}>
        <div style={{ display: "flex", gap: 12, alignItems: "flex-start" }}>
          <div style={{ fontSize: 18 }}>💡</div>
          <div>
            <div style={{ fontSize: 13, fontWeight: 700, color: T.slate900, marginBottom: 4 }}>How Claude uses this memory</div>
            <div style={{ fontSize: 12, color: T.slate700, lineHeight: 1.6 }}>
              Every active entry here is passed to Claude as context at the start of each conversation. Claude uses it to give you answers that are specific to your agency — not generic advice. The more complete and accurate this memory is, the more useful your Claude becomes. You and Claude can both add, edit, and update these entries at any time.
            </div>
          </div>
        </div>
      </Card>

      {/* Search */}
      <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search memories…"
        style={{ width: "100%", padding: "10px 14px", fontSize: 12, color: T.slate800, border: `1px solid ${T.slate200}`, borderRadius: 10, marginBottom: 16, outline: "none", background: T.white, boxSizing: "border-box" }} />

      {loading ? (
        <Card><div style={{ fontSize: 12, color: T.slate500, textAlign: "center", padding: 30 }}>Loading…</div></Card>
      ) : totalCount === 0 ? (
        <Card>
          <div style={{ textAlign: "center", padding: 30 }}>
            <div style={{ fontSize: 24, marginBottom: 8 }}>🧠</div>
            <div style={{ fontSize: 14, fontWeight: 600, color: T.slate800, marginBottom: 6 }}>No memories yet</div>
            <div style={{ fontSize: 12, color: T.slate500, marginBottom: 14 }}>Add the first entry to start building Claude's knowledge of the agency.</div>
            <Btn kind="primary" onClick={() => setModalState({ open: true, entry: null })}>+ Add your first memory</Btn>
          </div>
        </Card>
      ) : (
        <div style={{ display: "grid", gridTemplateColumns: "minmax(0,240px) minmax(0,1fr)", gap: 16, alignItems: "flex-start" }}>
          {/* Left rail: categories */}
          <Card style={{ padding: 12 }}>
            <button onClick={() => setActiveCategory("all")}
              style={{ display: "flex", justifyContent: "space-between", alignItems: "center", width: "100%", padding: "9px 11px", marginBottom: 4, fontSize: 12, fontWeight: 700, color: activeCategory === "all" ? T.white : T.slate900, background: activeCategory === "all" ? T.navy : "transparent", border: "none", borderRadius: 8, cursor: "pointer", textAlign: "left" }}>
              <span>All Memories</span>
              <span style={{ fontSize: 11, fontWeight: 700, padding: "1px 8px", borderRadius: 10, background: activeCategory === "all" ? T.white : T.slate100, color: activeCategory === "all" ? T.navy : T.slate600 }}>{totalCount}</span>
            </button>
            {Object.entries(categoryCounts).sort(([a], [b]) => a.localeCompare(b)).map(([cat, count]) => (
              <button key={cat} onClick={() => setActiveCategory(cat)}
                style={{ display: "flex", justifyContent: "space-between", alignItems: "center", width: "100%", padding: "8px 11px", marginBottom: 2, fontSize: 12, fontWeight: 500, color: activeCategory === cat ? T.navy : T.slate700, background: activeCategory === cat ? T.blueLt : "transparent", border: "none", borderRadius: 8, cursor: "pointer", textAlign: "left" }}>
                <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", marginRight: 8 }}>{labelFor(cat)}</span>
                <span style={{ fontSize: 11, fontWeight: 600, padding: "1px 8px", borderRadius: 10, background: T.slate100, color: T.slate600, flexShrink: 0 }}>{count}</span>
              </button>
            ))}
          </Card>

          {/* Right pane: entries */}
          <div>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 10 }}>
              <div style={{ fontSize: 13, fontWeight: 700, color: T.slate800 }}>{visibleHeader}</div>
              <div style={{ fontSize: 11, color: T.slate500 }}>{filtered.length} {filtered.length === 1 ? "entry" : "entries"}</div>
            </div>
            {filtered.length === 0 ? (
              <Card><div style={{ fontSize: 12, color: T.slate500, textAlign: "center", padding: 24 }}>No matches.</div></Card>
            ) : (
              filtered.map(entry => (
                <MemoryCard key={entry.id} entry={entry} onEdit={(e) => setModalState({ open: true, entry: e })} onDelete={handleDelete} />
              ))
            )}
          </div>
        </div>
      )}

      {modalState.open && (
        <MemoryModal initial={modalState.entry} onSave={handleSave} onCancel={() => setModalState({ open: false, entry: null })} />
      )}
    </div>
  );
}
