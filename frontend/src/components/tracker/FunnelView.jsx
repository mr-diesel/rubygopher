import { useEffect, useState } from "react";
import { fetchFunnel } from "../../api/tracker";
import { label } from "../../lib/tracker";

const PERIODS = [
  { id: "all", label: "All time", days: null },
  { id: "90", label: "90 days", days: 90 },
  { id: "30", label: "30 days", days: 30 }
];

const pct = (v) => (v == null ? "—" : `${v}%`);
const sinceFor = (days) => (days ? new Date(Date.now() - days * 86_400_000).toISOString() : undefined);

export default function FunnelView() {
  const [period, setPeriod] = useState("all");
  const [funnel, setFunnel] = useState(null);

  useEffect(() => {
    fetchFunnel(sinceFor(PERIODS.find((p) => p.id === period).days)).then(setFunnel).catch(() => setFunnel(null));
  }, [period]);

  if (!funnel) return <p className="dim">Loading…</p>;
  const apps = funnel.applications;

  return (
    <div className="funnel">
      <div className="funnel-bar">
        <div className="segmented">
          {PERIODS.map((p) => (
            <button key={p.id} className={p.id === period ? "active" : ""} onClick={() => setPeriod(p.id)}>{p.label}</button>
          ))}
        </div>
      </div>

      <div className="stat-tiles">
        <Tile value={apps.total} caption="applications" />
        <Tile value={pct(apps.response_rate)} caption="got a reply" />
        <Tile value={apps.median_days_to_response == null ? "—" : `${apps.median_days_to_response} d`} caption="median time to first reply" />
        <Tile value={apps.rejected} caption="rejected" />
      </div>

      <Bars title="Applications" stages={apps.stages} />
      <Bars title="Cold outreach" stages={funnel.outreach.stages} total={funnel.outreach.total} rejected={funnel.outreach.rejected} />
    </div>
  );
}

function Tile({ value, caption }) {
  return (
    <div className="stat-tile">
      <strong>{value}</strong>
      <span>{caption}</span>
    </div>
  );
}

// One series, so no legend: the title names it, each bar carries its own number.
function Bars({ title, stages, rejected }) {
  const max = Math.max(1, ...stages.map((s) => s.count));
  return (
    <section className="funnel-section">
      <h4>{title}{rejected != null && <span className="dim"> · rejected {rejected}</span>}</h4>
      <table className="funnel-table">
        <tbody>
          {stages.map((s) => (
            <tr key={s.name} title={`${s.count} reached ${label(s.name)} · ${pct(s.of_total)} of all · ${pct(s.of_previous)} of the previous stage`}>
              <th>{label(s.name)}</th>
              <td className="funnel-cell">
                <div className="funnel-fill" style={{ width: `${(s.count / max) * 100}%` }} />
                <span className="funnel-count">{s.count}</span>
              </td>
              <td className="funnel-pct">{pct(s.of_previous)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
