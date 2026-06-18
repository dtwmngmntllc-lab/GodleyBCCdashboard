import { useState, useEffect, createContext, useContext } from "react";

import Dashboard from "./src/modules/Dashboard.jsx";
import Financials from "./src/modules/Financials.jsx";
import PersistentMemory from "./src/modules/PersistentMemory.jsx";
import ComplianceCenter from "./src/modules/ComplianceCenter.jsx";
import Automations from "./src/modules/Automations.jsx";
import SocialMedia from "./src/modules/SocialMedia.jsx";
import TasksGoals from "./src/modules/TasksGoals.jsx";
import AlertsNotifications from "./src/modules/AlertsNotifications.jsx";
import Documents from "./src/modules/Documents.jsx";
import HRPeople from "./src/modules/HRPeople.jsx";
import Settings from "./src/modules/Settings.jsx";
import ErrorBoundary from "./src/components/ErrorBoundary.jsx";
import { supabase, AGENCY_ID } from "./src/lib/supabase.js";
import DemoBanner from "./src/components/DemoBanner.jsx";


// ============================================================
// BCC APP SHELL v1.0
// Business Command Center — State Farm Agent Edition
// Built by Imaginary Farms LLC · imaginary-farms.com
//
// ARCHITECTURE:
// ┌──────────────────────────────────────────────────────┐