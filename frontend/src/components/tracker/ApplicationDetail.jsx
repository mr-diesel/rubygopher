import { useState } from "react";
import { addApplicationEvent } from "../../api/tracker";
import { APPLICATION_STATUSES, EVENT_TYPES, errorMessage, fmtDate, fmtDateTime, label, toIso } from "../../lib/tracker";

const emptyEvent = { event_type: "status_changed", status: "", comment: "", occurred_at: "", next_follow_up_at: "" };

export default function ApplicationDetail({ application, onChanged }) {
  const [draft, setDraft] = useState(emptyEvent);
  const [error, setError] = useState(null);
  const set = (field) => (e) => setDraft((d) => ({ ...d, [field]: e.target.value }));

  const submit = async (e) => {
    e.preventDefault();
    setError(null);
    try {
      await addApplicationEvent(application.id, {
        event_type: draft.event_type,
        status: draft.event_type === "status_changed" ? draft.status || undefined : undefined,
        comment: draft.comment || undefined,
        occurred_at: toIso(draft.occurred_at),
        next_follow_up_at: draft.event_type === "follow_up_sent" || draft.next_follow_up_at ? toIso(draft.next_follow_up_at) ?? null : undefined
      });
      setDraft(emptyEvent);
      onChanged();
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const { company, vacancy } = application;
  return (
    <div className="tracker-detail">
      <div className="q-head">
        <h2>{company.name}</h2>
        <span className={`status status-${application.status}`}>{label(application.status)}</span>
      </div>
      <p className="tracker-detail__vacancy">
        {vacancy.url ? <a href={vacancy.url} target="_blank" rel="noreferrer">{vacancy.title}</a> : vacancy.title}
        {vacancy.language && <span className="badge">{vacancy.language}</span>}
        {vacancy.work_mode && <span className="badge">{vacancy.work_mode}</span>}
        {vacancy.location && <span className="dim"> · {vacancy.location}</span>}
      </p>
      <p className="dim">
        applied {fmtDate(application.applied_at)} · last activity {fmtDate(application.last_activity_at)}
        {application.next_follow_up_at && ` · follow up ${fmtDateTime(application.next_follow_up_at)}`}
      </p>

      <h4>History</h4>
      <ol className="timeline">
        {application.events.map((ev) => (
          <li key={ev.id}>
            <span className="timeline__when">{fmtDateTime(ev.occurred_at)}</span>
            <span className="timeline__what">
              {label(ev.event_type)}
              {ev.status && <span className={`status status-${ev.status}`}>{label(ev.status)}</span>}
            </span>
            {ev.comment && <span className="timeline__comment">{ev.comment}</span>}
          </li>
        ))}
      </ol>

      <form className="q-form tracker-event-form" onSubmit={submit}>
        <h4>Add to history</h4>
        <div className="form-row">
          <select value={draft.event_type} onChange={set("event_type")}>
            {EVENT_TYPES.map((t) => <option key={t} value={t}>{label(t)}</option>)}
          </select>
          {draft.event_type === "status_changed" && (
            <select value={draft.status} onChange={set("status")} required>
              <option value="">status…</option>
              {APPLICATION_STATUSES.map((s) => <option key={s} value={s}>{label(s)}</option>)}
            </select>
          )}
        </div>
        <input value={draft.comment} onChange={set("comment")} placeholder="comment" />
        <div className="form-row">
          <label className="field-label">when<input type="datetime-local" value={draft.occurred_at} onChange={set("occurred_at")} /></label>
          <label className="field-label">next follow-up<input type="datetime-local" value={draft.next_follow_up_at} onChange={set("next_follow_up_at")} /></label>
        </div>
        {error && <p className="form-error">{error}</p>}
        <div className="form-actions">
          <button type="submit">Save</button>
        </div>
      </form>
    </div>
  );
}
