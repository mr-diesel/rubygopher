import { useEffect, useState } from "react";
import { apiTokenStatus, regenerateApiToken, revokeApiToken } from "../api/apiToken";
import { API_BASE } from "../config";

const fmt = (iso) => (iso ? new Date(iso).toLocaleString() : "never");

export default function ApiTokenPanel() {
  const [state, setState] = useState(null);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    apiTokenStatus().then(setState).catch(() => {});
  }, []);

  if (!state) return null;

  const regenerate = async () => {
    if (state.token && !window.confirm("The current token will stop working everywhere it is pasted. Continue?")) return;
    setState(await regenerateApiToken());
  };
  const revoke = async () => {
    if (!window.confirm("Revoke the token?")) return;
    await revokeApiToken();
    setState(await apiTokenStatus());
  };
  const copy = async () => {
    await navigator.clipboard?.writeText(state.token);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  return (
    <div className="settings-block">
      <p className="dim">
        Give this token to an AI assistant (ChatGPT, Claude) so it can keep your tracker: schema at{" "}
        <a href={`${API_BASE}/openapi.json`} target="_blank" rel="noreferrer">openapi.json</a>, instructions at{" "}
        <a href={`${API_BASE}/agent/guide`} target="_blank" rel="noreferrer">agent/guide</a>.
      </p>
      {state.token ? (
        <>
          <code className="token">{state.token}</code>
          <p className="dim">
            issued {fmt(state.generated_at)} · last used {fmt(state.last_used_at)}
          </p>
          <div className="form-actions">
            <button className="ghost" onClick={copy}>{copied ? "Copied" : "Copy"}</button>
            <button className="ghost" onClick={regenerate}>Regenerate</button>
            <button className="ghost danger" onClick={revoke}>Revoke</button>
          </div>
        </>
      ) : (
        <div className="form-actions">
          <button className="ghost" onClick={regenerate}>Create token</button>
        </div>
      )}
    </div>
  );
}
