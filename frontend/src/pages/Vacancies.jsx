import { useCallback, useEffect, useState } from "react";
import { listVacancies } from "../api/vacancies";
import { createApplication } from "../api/tracker";
import { markVacanciesSeen } from "../api/digest";
import { errorMessage, fmtDate, label } from "../lib/tracker";

const SOURCES = ["hh", "habr_career", "getmatch", "hirify"];
const EMPTY = { language: "", work_mode: "", source: "", only_new: false, q: "" };

const salary = (v) => {
  if (!v.salary_min && !v.salary_max) return null;
  const n = (x) => x.toLocaleString();
  const range = v.salary_min && v.salary_max ? `${n(v.salary_min)}–${n(v.salary_max)}` : v.salary_min ? `from ${n(v.salary_min)}` : `to ${n(v.salary_max)}`;
  return `${range} ${v.currency || ""}`.trim();
};

export default function Vacancies({ onDigestChange }) {
  const [filters, setFilters] = useState(EMPTY);
  const [page, setPage] = useState(1);
  const [feed, setFeed] = useState(null);
  const [error, setError] = useState(null);

  const set = (field) => (e) => {
    setFilters((f) => ({ ...f, [field]: e.target.type === "checkbox" ? e.target.checked : e.target.value }));
    setPage(1);
  };

  const load = useCallback(
    () => listVacancies({ ...filters, page }).then(setFeed).catch((e) => setError(errorMessage(e))),
    [filters, page]
  );

  useEffect(() => {
    load();
  }, [load]);

  const apply = async (vacancy) => {
    setError(null);
    try {
      await createApplication({ url: vacancy.postings[0].url, company_name: vacancy.company.name, vacancy_title: vacancy.title });
      await load();
      onDigestChange?.();
    } catch (e) {
      setError(errorMessage(e));
    }
  };

  const seen = async () => {
    await markVacanciesSeen();
    await load();
    onDigestChange?.();
  };

  const pages = feed ? Math.ceil(feed.total / feed.per_page) : 0;

  return (
    <div className="feed">
      <div className="feed-filters">
        <input value={filters.q} onChange={set("q")} placeholder="search title or description" />
        <select value={filters.language} onChange={set("language")}>
          <option value="">any language</option>
          <option value="ruby">Ruby</option>
          <option value="go">Go</option>
        </select>
        <select value={filters.work_mode} onChange={set("work_mode")}>
          <option value="">any work mode</option>
          {["remote", "hybrid", "onsite"].map((m) => <option key={m} value={m}>{m}</option>)}
        </select>
        <select value={filters.source} onChange={set("source")}>
          <option value="">any source</option>
          {SOURCES.map((s) => <option key={s} value={s}>{label(s)}</option>)}
        </select>
        <label className="feed-check"><input type="checkbox" checked={filters.only_new} onChange={set("only_new")} /> only new</label>
        <button className="ghost" onClick={seen} title="Everything currently in the feed stops counting as new">Mark all seen</button>
        {feed && <span className="dim">{feed.total} vacancies</span>}
      </div>

      {error && <p className="form-error">{error}</p>}
      {!feed && <p className="dim">Loading…</p>}
      {feed && feed.vacancies.length === 0 && <p className="dim">Nothing matches. The fetcher runs every 15 minutes.</p>}

      <div className="feed-list">
        {feed?.vacancies.map((v) => (
          <article key={v.id} className={`feed-card${v.new ? " new" : ""}`}>
            <div className="feed-card__head">
              <h3>{v.title}</h3>
              {v.new && <span className="badge">new</span>}
              {v.language && <span className="badge">{v.language}</span>}
              {v.work_mode && <span className="badge">{v.work_mode}</span>}
            </div>
            <p className="feed-card__meta">
              <strong>{v.company.name}</strong>
              {v.location && <span> · {v.location}</span>}
              {salary(v) && <span> · {salary(v)}</span>}
              {v.published_at && <span className="dim"> · {fmtDate(v.published_at)}</span>}
            </p>
            <div className="feed-card__actions">
              {v.postings.map((p) => (
                <a key={p.url} href={p.url} target="_blank" rel="noreferrer" className="ghost">{label(p.source)} ↗</a>
              ))}
              {v.application_id ? (
                <span className="status status-applied">applied</span>
              ) : (
                <button className="ghost accent" onClick={() => apply(v)}>I applied</button>
              )}
            </div>
          </article>
        ))}
      </div>

      {pages > 1 && (
        <div className="feed-pager">
          <button className="ghost" disabled={page <= 1} onClick={() => setPage(page - 1)}>← prev</button>
          <span className="dim">page {page} of {pages}</span>
          <button className="ghost" disabled={page >= pages} onClick={() => setPage(page + 1)}>next →</button>
        </div>
      )}
    </div>
  );
}
