import { useState } from "react";
import { interviewPrompt } from "../../api/interview";
import { errorMessage } from "../../lib/tracker";

export default function InterviewPrompt({ applicationId }) {
  const [result, setResult] = useState(null);
  const [copied, setCopied] = useState(false);
  const [error, setError] = useState(null);

  const load = async () => {
    setError(null);
    try {
      setResult(await interviewPrompt(applicationId));
    } catch (e) {
      setError(errorMessage(e));
    }
  };

  const copy = async () => {
    await navigator.clipboard?.writeText(result.prompt);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  return (
    <div className="interview-prompt">
      <div className="form-actions">
        {result ? (
          <>
            <button className="ghost accent" onClick={copy}>{copied ? "Copied" : "Copy prompt"}</button>
            <button className="ghost" onClick={() => setResult(null)}>Hide</button>
          </>
        ) : (
          <button className="ghost" onClick={load} title="Build a prompt to run a mock interview in any chat assistant">Mock interview prompt</button>
        )}
      </div>
      {error && <p className="form-error">{error}</p>}
      {result && (
        <>
          {result.missing_skills.length > 0 && (
            <p className="dim">The vacancy mentions what your résumé does not: {result.missing_skills.join(", ")}.</p>
          )}
          <textarea className="interview-prompt__text" value={result.prompt} readOnly rows={14} />
          <p className="dim">Paste it into any chat, or ask an assistant connected over MCP to run the <code>mock_interview</code> prompt.</p>
        </>
      )}
    </div>
  );
}
