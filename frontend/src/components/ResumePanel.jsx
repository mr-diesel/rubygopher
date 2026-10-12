import { useEffect, useState } from "react";
import { getProfile, updateProfile } from "../api/profile";
import { errorMessage } from "../lib/tracker";

export default function ResumePanel() {
  const [resume, setResume] = useState(null);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    getProfile().then((p) => setResume(p.resume || "")).catch(() => setResume(""));
  }, []);

  if (resume === null) return null;

  const save = async () => {
    setError(null);
    try {
      await updateProfile({ resume: resume.trim() || null });
      setSaved(true);
      setTimeout(() => setSaved(false), 1500);
    } catch (e) {
      setError(errorMessage(e));
    }
  };

  return (
    <div className="settings-block">
      <p className="dim">Paste your résumé as text or Markdown. Mock-interview prompts quote it and compare its skills with the vacancy.</p>
      <textarea className="resume" value={resume} onChange={(e) => setResume(e.target.value)} rows={8} placeholder="Senior Ruby developer, 5 years…" />
      {error && <p className="form-error">{error}</p>}
      <div className="form-actions">
        <button className="ghost" onClick={save}>{saved ? "Saved" : "Save"}</button>
      </div>
    </div>
  );
}
