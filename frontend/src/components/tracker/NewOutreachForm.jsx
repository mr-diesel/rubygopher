import { useState } from "react";
import { createOutreach } from "../../api/tracker";
import { errorMessage, toIso } from "../../lib/tracker";

export default function NewOutreachForm({ onCreated, onCancel }) {
  const [draft, setDraft] = useState({ company_name: "", sent_at: "", notes: "" });
  const [error, setError] = useState(null);
  const set = (field) => (e) => setDraft((d) => ({ ...d, [field]: e.target.value }));

  const submit = async (e) => {
    e.preventDefault();
    setError(null);
    try {
      onCreated(await createOutreach({ company_name: draft.company_name, sent_at: toIso(draft.sent_at), notes: draft.notes || undefined }));
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  return (
    <form className="q-form" onSubmit={submit}>
      <h3>New cold outreach</h3>
      <label className="field-label">Company</label>
      <input value={draft.company_name} onChange={set("company_name")} required autoFocus />
      <label className="field-label">Sent at (defaults to now)</label>
      <input type="datetime-local" value={draft.sent_at} onChange={set("sent_at")} />
      <label className="field-label">Notes</label>
      <textarea value={draft.notes} onChange={set("notes")} rows={4} placeholder="whom you wrote to and what you said" />
      {error && <p className="form-error">{error}</p>}
      <div className="form-actions">
        <button type="submit">Record outreach</button>
        <button type="button" className="ghost" onClick={onCancel}>Cancel</button>
      </div>
    </form>
  );
}
