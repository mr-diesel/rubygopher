import { useState } from "react";
import { changeOutreachStatus } from "../../api/tracker";
import { OUTREACH_STATUSES, errorMessage, fmtDate, fmtDateTime, label } from "../../lib/tracker";

export default function OutreachDetail({ outreach, onChanged }) {
  const [draft, setDraft] = useState({ status: "", comment: "" });
  const [error, setError] = useState(null);

  const submit = async (e) => {
    e.preventDefault();
    setError(null);
    try {
      await changeOutreachStatus(outreach.id, { status: draft.status, comment: draft.comment || undefined });
      setDraft({ status: "", comment: "" });
      onChanged();
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  return (
    <div className="tracker-detail">
      <div className="q-head">
        <h2>{outreach.company.name}</h2>
        <span className={`status status-${outreach.status}`}>{label(outreach.status)}</span>
      </div>
      <p className="dim">sent {fmtDate(outreach.sent_at)}</p>
      {outreach.notes && <p className="tracker-detail__notes">{outreach.notes}</p>}

      <h4>History</h4>
      <ol className="timeline">
        {outreach.events.map((ev) => (
          <li key={ev.id}>
            <span className="timeline__when">{fmtDateTime(ev.changed_at)}</span>
            <span className="timeline__what"><span className={`status status-${ev.status}`}>{label(ev.status)}</span></span>
            {ev.comment && <span className="timeline__comment">{ev.comment}</span>}
          </li>
        ))}
      </ol>

      <form className="q-form tracker-event-form" onSubmit={submit}>
        <h4>Change status</h4>
        <div className="form-row">
          <select value={draft.status} onChange={(e) => setDraft((d) => ({ ...d, status: e.target.value }))} required>
            <option value="">status…</option>
            {OUTREACH_STATUSES.map((s) => <option key={s} value={s}>{label(s)}</option>)}
          </select>
          <input value={draft.comment} onChange={(e) => setDraft((d) => ({ ...d, comment: e.target.value }))} placeholder="comment" />
        </div>
        {error && <p className="form-error">{error}</p>}
        <div className="form-actions">
          <button type="submit">Save</button>
        </div>
      </form>
    </div>
  );
}
