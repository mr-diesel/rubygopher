import { useState } from "react";
import { useTrackerList } from "../hooks/useTracker";
import { APPLICATION_STATUSES, OUTREACH_STATUSES, label } from "../lib/tracker";
import TrackerList from "../components/tracker/TrackerList";
import ApplicationDetail from "../components/tracker/ApplicationDetail";
import OutreachDetail from "../components/tracker/OutreachDetail";
import NewApplicationForm from "../components/tracker/NewApplicationForm";
import NewOutreachForm from "../components/tracker/NewOutreachForm";
import FunnelView from "../components/tracker/FunnelView";

const KINDS = [
  { id: "applications", label: "Applications", statuses: APPLICATION_STATUSES },
  { id: "outreaches", label: "Cold outreach", statuses: OUTREACH_STATUSES },
  { id: "funnel", label: "Funnel", statuses: [] }
];

export default function Tracker() {
  const [kind, setKind] = useState("applications");
  const [status, setStatus] = useState("");
  const [creating, setCreating] = useState(false);
  const listKind = kind === "funnel" ? "applications" : kind;
  const { items, loading, selectedId, detail, select, reload } = useTrackerList(listKind, status);

  const switchKind = (next) => {
    setKind(next);
    setStatus("");
    setCreating(false);
  };

  const created = async (item) => {
    setCreating(false);
    await reload(item.id);
  };

  const current = KINDS.find((k) => k.id === kind);

  if (kind === "funnel") {
    return (
      <div className="helper tracker">
        <div className="q-col tracker-col">
          <div className="segmented">
            {KINDS.map((k) => (
              <button key={k.id} className={k.id === kind ? "active" : ""} onClick={() => switchKind(k.id)}>{k.label}</button>
            ))}
          </div>
        </div>
        <div className="helper-main"><FunnelView /></div>
      </div>
    );
  }

  return (
    <div className="helper tracker">
      <div className="q-col tracker-col">
        <div className="segmented">
          {KINDS.map((k) => (
            <button key={k.id} className={k.id === kind ? "active" : ""} onClick={() => switchKind(k.id)}>{k.label}</button>
          ))}
        </div>
        <select className="tracker-filter" value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">all statuses</option>
          {current.statuses.map((s) => <option key={s} value={s}>{label(s)}</option>)}
        </select>

        <TrackerList kind={kind} items={items} selectedId={selectedId} loading={loading} onSelect={(id) => { setCreating(false); select(id); }} />

        <button className="new-btn" onClick={() => setCreating(true)}>+ {kind === "applications" ? "Application" : "Outreach"}</button>
      </div>

      <div className="helper-main">
        {creating && kind === "applications" && <NewApplicationForm onCreated={created} onCancel={() => setCreating(false)} />}
        {creating && kind === "outreaches" && <NewOutreachForm onCreated={created} onCancel={() => setCreating(false)} />}
        {!creating && detail && kind === "applications" && <ApplicationDetail application={detail} onChanged={() => reload()} />}
        {!creating && detail && kind === "outreaches" && <OutreachDetail outreach={detail} onChanged={() => reload()} />}
        {!creating && !detail && (
          <p className="dim">
            {kind === "applications"
              ? "Paste a vacancy link to record an application, or pick one on the left."
              : "Record whom you wrote to, or pick an outreach on the left."}
          </p>
        )}
      </div>
    </div>
  );
}
