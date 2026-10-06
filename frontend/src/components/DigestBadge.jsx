import { useEffect, useRef, useState } from "react";
import { markFollowUpSent, markVacanciesSeen } from "../api/digest";

const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

const daysOverdue = (iso) => Math.floor((Date.now() - new Date(iso)) / (24 * 60 * 60 * 1000));

export default function DigestBadge({ digest, onChange }) {
  const [open, setOpen] = useState(false);
  const root = useRef(null);

  useEffect(() => {
    if (!open) return undefined;
    const close = (e) => root.current && !root.current.contains(e.target) && setOpen(false);
    document.addEventListener("mousedown", close);
    return () => document.removeEventListener("mousedown", close);
  }, [open]);

  if (!digest) return null;

  const due = digest.follow_ups.due;
  const upcoming = digest.follow_ups.upcoming;
  const newVacancies = digest.new_vacancies.count;
  const total = due.length + newVacancies;

  const sent = async (application) => {
    await markFollowUpSent(application.id, new Date(Date.now() + WEEK_MS).toISOString());
    onChange();
  };

  const seen = async () => {
    await markVacanciesSeen();
    onChange();
  };

  return (
    <div className="digest" ref={root}>
      <button className={total ? "digest-btn attention" : "digest-btn"} onClick={() => setOpen((v) => !v)} title="Follow-ups and new vacancies">
        ⏰ {due.length} · 🆕 {newVacancies}
      </button>

      {open && (
        <div className="digest-panel">
          <section>
            <h4>Follow-ups due</h4>
            {due.length === 0 && <p className="dim">Nothing is overdue.</p>}
            {due.map((a) => (
              <div key={a.id} className="digest-row">
                <span>
                  <strong>{a.company.name}</strong> · {a.vacancy.title}
                  <small>{daysOverdue(a.next_follow_up_at)} d overdue</small>
                </span>
                <button className="ghost" onClick={() => sent(a)} title="Record a follow-up and remind me again in a week">
                  Sent
                </button>
              </div>
            ))}
          </section>

          {upcoming.length > 0 && (
            <section>
              <h4>Coming up</h4>
              {upcoming.map((a) => (
                <div key={a.id} className="digest-row">
                  <span>
                    <strong>{a.company.name}</strong> · {a.vacancy.title}
                    <small>{new Date(a.next_follow_up_at).toLocaleDateString()}</small>
                  </span>
                </div>
              ))}
            </section>
          )}

          <section>
            <h4>New vacancies</h4>
            <div className="digest-row">
              <span>{newVacancies ? `${newVacancies} new since ${new Date(digest.new_vacancies.since).toLocaleDateString()}` : "No new vacancies yet."}</span>
              {newVacancies > 0 && (
                <button className="ghost" onClick={seen}>
                  Mark seen
                </button>
              )}
            </div>
          </section>
        </div>
      )}
    </div>
  );
}
