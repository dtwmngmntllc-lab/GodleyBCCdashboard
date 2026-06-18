import { useEffect, useState } from "react";
import { supabase } from "./supabase.js";

// ============================================================
// BCC CONNECTIONS HELPER v1.0
// Built by Imaginary Farms LLC · imaginary-farms.com
//
// Single source of truth for the Connection Health card
// (Automations module) and the Connections tab (Settings).
//
// Returns a unified array of connection objects across:
//   1. SYSTEM integrations — Gmail, Google Drive, Composio,
//      Supabase, GitHub, Vercel. These power the BCC itself.
//      Status is derived from settings + agency rows.
//   2. SOCIAL platforms — Facebook, Instagram, LinkedIn,
//      X/Twitter. Status comes straight from social_accounts.
//
// Each connection has the shape:
//   { id, group, platform, icon, account, status, last_sync, note }
// where status ∈ "healthy" | "error" | "manual" | "pending"
// ============================================================

const SYSTEM_PLATFORMS = [
  { key:"gmail",    label:"Gmail",         icon:"📧", note:"Inbox intake for documents and the Daily Briefing sender" },
  { key:"drive",    label:"Google Drive",  icon:"📁", note:"Archive for every processed document, filed by month" },
  { key:"calendar", label:"Google Calendar",icon:"📅",note:"Compliance and operational deadline tracking" },
  { key:"composio", label:"Composio",      icon:"🔌", note:"Gateway that runs every automation recipe" },
  { key:"supabase", label:"Supabase",      icon:"💾", note:"Database — everything you see in the BCC reads from here" },
  { key:"github",   label:"GitHub",        icon:"📦", note:"BCC source code repository" },
  { key:"vercel",   label:"Vercel",        icon:"🚀", note:"Hosts this BCC web app" },
];

const SOCIAL_PLATFORMS = [
  { key:"facebook",  label:"Facebook",  icon:"👥", note:"Auto-scheduled posts via Composio" },
  { key:"instagram", label:"Instagram", icon:"📸", note:"Manual daily posting — Instagram API does not support auto-scheduling", forceManual:true },
  { key:"linkedin",  label:"LinkedIn",  icon:"💼", note:"Auto-scheduled posts via Composio" },
  { key:"twitter",   label:"X/Twitter", icon:"𝕏",  note:"Auto-scheduled posts via Composio" },
];

// Map a settings row key to which system platform it belongs to.
// Anything not in this map is ignored for connection display.
const SETTINGS_TO_PLATFORM = {
  composio_gmail_account_id:    "gmail",
  composio_drive_account_id:    "drive",
  composio_calendar_account_id: "calendar",
  composio_user_id:             "composio",
  composio_api_key:             "composio",
  composio_supabase_account_id: "supabase",
  composio_github_account_id:   "github",
};

function buildSystemConnection(platform, settingsByKey, agencyRow) {
  const account = (() => {
    if (platform.key === "gmail" || platform.key === "drive" || platform.key === "calendar") {
      return agencyRow?.google_account_email || agencyRow?.primary_email || "—";
    }
    if (platform.key === "vercel") return agencyRow?.vercel_url || "Hosted at the BCC URL";
    if (platform.key === "supabase") return "BCC database (Supabase project)";
    if (platform.key === "composio") return "Composio workspace";
    if (platform.key === "github") return "GodleyBCCdashboard repository";
    return "—";
  })();

  // Detect connection: at least one relevant settings row present.
  const relatedKeys = Object.entries(SETTINGS_TO_PLATFORM)
    .filter(([, p]) => p === platform.key)
    .map(([k]) => k);
  const hasSetting = relatedKeys.some(k => settingsByKey[k]);
  // Vercel + Supabase + GitHub are intrinsic to the install — they
  // can't be "not connected" once the BCC is running.
  const intrinsic = platform.key === "vercel" || platform.key === "supabase" || platform.key === "github";
  const status = (hasSetting || intrinsic) ? "healthy" : "pending";

  return {
    id:        `sys-${platform.key}`,
    group:     "system",
    platform:  platform.label,
    icon:      platform.icon,
    account,
    connected_account: account,
    status,
    last_sync: status === "healthy" ? "Active" : "—",
    note:      platform.note,
  };
}

function buildSocialConnection(platform, socialRow) {
  // No row in social_accounts => pending (Deatria hasn't authorized yet)
  if (!socialRow) {
    return {
      id:        `social-${platform.key}`,
      group:     "social",
      platform:  platform.label,
      icon:      platform.icon,
      account:   "Not yet connected",
      connected_account: "Not yet connected",
      status:    platform.forceManual ? "manual" : "pending",
      last_sync: "—",
      note:      platform.forceManual
        ? platform.note
        : "Authorize via Composio to enable auto-posting",
    };
  }
  const connected = socialRow.is_connected === true;
  let status;
  if (platform.forceManual) status = "manual";
  else if (connected) status = "healthy";
  else status = "pending";

  const acct = socialRow.account_handle || socialRow.account_id || "Not yet connected";
  return {
    id:        socialRow.id || `social-${platform.key}`,
    group:     "social",
    platform:  platform.label,
    icon:      platform.icon,
    account:   acct,
    connected_account: acct,
    status,
    last_sync: socialRow.last_sync
      ? new Date(socialRow.last_sync).toLocaleString("en-US",
          { month:"short", day:"numeric", hour:"numeric", minute:"2-digit" })
      : (connected ? "Active" : "—"),
    note:      socialRow.notes || platform.note,
  };
}

export function buildConnections({ agency, settingsRows, socialRows }) {
  const settingsByKey = (settingsRows || []).reduce((acc, row) => {
    if (row?.setting_key) acc[row.setting_key] = row.setting_value;
    return acc;
  }, {});

  const socialByPlatform = (socialRows || []).reduce((acc, row) => {
    if (row?.platform) acc[row.platform.toLowerCase()] = row;
    return acc;
  }, {});

  const system = SYSTEM_PLATFORMS.map(p => buildSystemConnection(p, settingsByKey, agency || {}));
  const social = SOCIAL_PLATFORMS.map(p => buildSocialConnection(p, socialByPlatform[p.key]));

  return [...system, ...social];
}

// React hook used by both Automations and Settings.
// Loads agency, settings, social_accounts once and rebuilds the
// unified list. Caller can refetch by changing the agencyId.
export function useConnections(agencyId) {
  const [connections, setConnections] = useState([]);
  const [loading, setLoading]         = useState(true);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      if (!supabase || !agencyId) { setLoading(false); return; }
      try {
        const [agencyRes, settingsRes, socialRes] = await Promise.all([
          supabase.from("agency").select("primary_email,google_account_email,vercel_url").eq("id", agencyId).single(),
          supabase.from("settings").select("setting_key,setting_value").eq("agency_id", agencyId),
          supabase.from("social_accounts").select("*").eq("agency_id", agencyId),
        ]);
        if (cancelled) return;
        const list = buildConnections({
          agency:       agencyRes?.data || {},
          settingsRows: settingsRes?.data || [],
          socialRows:   socialRes?.data || [],
        });
        setConnections(list);
      } catch (e) {
        console.warn("useConnections load error:", e);
        // Fall back to the empty-state system list so the UI still renders.
        setConnections(buildConnections({ agency:{}, settingsRows:[], socialRows:[] }));
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    return () => { cancelled = true; };
  }, [agencyId]);

  return { connections, loading };
}
