import { fmtDate, label } from "../../lib/tracker";

export default function TrackerList({ kind, items, selectedId, onSelect, loading }) {
  if (loading && items.length === 0) return <p className="dim">Loading…</p>;
  if (items.length === 0) return <p className="dim">Nothing here yet.</p>;

  return items.map((item) => {
    const subtitle = kind === "applications" ? item.vacancy.title : fmtDate(item.sent_at);
    const due = item.next_follow_up_at && new Date(item.next_follow_up_at) <= new Date();
    return (
      <button key={item.id} className={`tracker-row${item.id === selectedId ? " active" : ""}`} onClick={() => onSelect(item.id)}>
        <span className="tracker-row__title">{item.company.name}</span>
        <span className="tracker-row__sub">{subtitle}</span>
        <span className={`status status-${item.status}`}>{label(item.status)}</span>
        {due && <span className="tracker-row__due" title="follow-up is due">⏰</span>}
      </button>
    );
  });
}
