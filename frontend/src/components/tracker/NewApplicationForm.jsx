import { useState } from "react";
import { createApplication } from "../../api/tracker";
import { errorMessage, toIso } from "../../lib/tracker";

const empty = { url: "", company_name: "", vacancy_title: "", comment: "", next_follow_up_at: "" };

export default function NewApplicationForm({ onCreated, onCancel }) {
  const [draft, setDraft] = useState(empty);
  const [manual, setManual] = useState(false);
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);

  const set = (field) => (e) => setDraft((d) => ({ ...d, [field]: e.target.value }));

  const submit = async (e) => {
    e.preventDefault();
    setSaving(true);
    setError(null);
    try {
      const created = await createApplication({
        url: draft.url || undefined,
        company_name: manual ? draft.company_name : undefined,
        vacancy_title: manual ? draft.vacancy_title : undefined,
        comment: draft.comment || undefined,
        next_follow_up_at: toIso(draft.next_follow_up_at)
      });
      onCreated(created);
    } catch (err) {
      // A board we cannot read yet (or a plain company site) needs the names typed in.
      if (err.status === 422 && !manual) setManual(true);
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  return (
    <form className="q-form" onSubmit={submit}>
      <h3>New application</h3>
      <label className="field-label">Vacancy link (hh.ru, Habr Career, getmatch, hirify or the company site)</label>
      <input value={draft.url} onChange={set("url")} placeholder="https://hh.ru/vacancy/123456" autoFocus />

      {manual ? (
        <>
          <label className="field-label">Company</label>
          <input value={draft.company_name} onChange={set("company_name")} required />
          <label className="field-label">Vacancy title</label>
          <input value={draft.vacancy_title} onChange={set("vacancy_title")} required />
        </>
      ) : (
        <button type="button" className="ghost" onClick={() => setManual(true)}>
          Enter company and title by hand
        </button>
      )}

      <label className="field-label">Comment</label>
      <textarea value={draft.comment} onChange={set("comment")} rows={3} placeholder="how you applied, who referred you…" />
      <label className="field-label">Remind me to follow up</label>
      <input type="datetime-local" value={draft.next_follow_up_at} onChange={set("next_follow_up_at")} />

      {error && <p className="form-error">{error}</p>}
      <div className="form-actions">
        <button type="submit" disabled={saving}>{saving ? "Saving…" : "Record application"}</button>
        <button type="button" className="ghost" onClick={onCancel}>Cancel</button>
      </div>
    </form>
  );
}
