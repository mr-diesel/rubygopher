import { useEffect, useRef, useState } from "react";
import CodeEditor from "../components/CodeEditor";
import { runCode } from "../api/console";

const CODE_KEY = "console:code";
const CONTEXT_KEY = "console:context";

const SAMPLE = `# Ctrl+Enter (Cmd+Enter) runs the snippet.
# Only what you print shows up — use p, pp or puts.
# Every run is a fresh process — nothing carries over.

p User.count
`;

const CONTEXTS = [
  { id: "rails", label: "Rails", hint: "models + database" },
  { id: "ruby", label: "Plain Ruby", hint: "isolated, no Rails" }
];

// Server-side wall clock: process start-up (fork or spawn) plus the snippet itself.
const formatDuration = (ms) => (ms >= 1000 ? `${(ms / 1000).toFixed(2)} s` : `${ms} ms`);

const errorText = (data, status) => {
  const detail = data?.error || data?.errors;
  return typeof detail === "string" ? detail : detail ? JSON.stringify(detail) : `HTTP ${status}`;
};

export default function Console() {
  const [code, setCode] = useState(() => localStorage.getItem(CODE_KEY) ?? SAMPLE);
  const [context, setContext] = useState(() => localStorage.getItem(CONTEXT_KEY) || "rails");
  const [result, setResult] = useState(null);
  const [running, setRunning] = useState(false);
  const [split, setSplit] = useState(55); // % of the width taken by the editor
  const panes = useRef(null);
  const dragging = useRef(false);

  useEffect(() => localStorage.setItem(CODE_KEY, code), [code]);
  useEffect(() => localStorage.setItem(CONTEXT_KEY, context), [context]);

  useEffect(() => {
    const move = (e) => {
      if (!dragging.current || !panes.current) return;
      const { left, width } = panes.current.getBoundingClientRect();
      setSplit(Math.min(80, Math.max(20, ((e.clientX - left) / width) * 100)));
    };
    const stop = () => {
      dragging.current = false;
    };

    window.addEventListener("mousemove", move);
    window.addEventListener("mouseup", stop);
    return () => {
      window.removeEventListener("mousemove", move);
      window.removeEventListener("mouseup", stop);
    };
  }, []);

  const run = async () => {
    if (running || !code.trim()) return;
    setRunning(true);
    try {
      setResult(await runCode(code, context));
    } catch (e) {
      setResult({ error: { class: "RequestError", message: errorText(e.data, e.status) } });
    } finally {
      setRunning(false);
    }
  };

  const onKeyDown = (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === "Enter") {
      e.preventDefault();
      run();
    }
  };

  return (
    <div className="console" onKeyDown={onKeyDown}>
      <div className="console-bar">
        <button className="run-btn" onClick={run} disabled={running} title="Ctrl+Enter">
          {running ? "Running…" : "▶ Run"}
        </button>

        <div className="segmented">
          {CONTEXTS.map((c) => (
            <button
              key={c.id}
              className={context === c.id ? "active" : ""}
              onClick={() => setContext(c.id)}
              title={c.hint}
            >
              {c.label}
            </button>
          ))}
        </div>

        <button className="ghost" onClick={() => setResult(null)}>
          Clear output
        </button>
      </div>

      <div className="console-panes" ref={panes}>
        <div className="console-pane" style={{ width: `${split}%` }}>
          <CodeEditor value={code} onChange={setCode} />
        </div>

        <div className="console-divider" onMouseDown={() => (dragging.current = true)} />

        <div className="console-pane console-result" style={{ width: `${100 - split}%` }}>
          <Output result={result} running={running} />

          {result && !running && (
            <div className="console-timing">
              ran in {formatDuration(result.duration_ms)} · {result.context}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function Output({ result, running }) {
  if (running) return <pre className="out-dim">Running…</pre>;
  if (!result) return <pre className="out-dim">Run the snippet to see what it prints.</pre>;

  const { output, error } = result;

  return (
    <>
      {output && <pre className="out-stdout">{output}</pre>}
      {error && (
        <div className="out-error">
          <pre>
            {error.class}: {error.message}
          </pre>
          {error.backtrace?.length > 0 && (
            <details>
              <summary>backtrace</summary>
              <pre>{error.backtrace.join("\n")}</pre>
            </details>
          )}
        </div>
      )}
      {!output && !error && <pre className="out-dim">(nothing printed — use p, pp or puts)</pre>}
    </>
  );
}
