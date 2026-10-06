import { useEffect, useRef, useState } from "react";
import CodeEditor from "../components/CodeEditor";
import { runCode } from "../api/console";
import { createSession, fetchSession } from "../api/consoleSessions";
import { useConsoleSession } from "../hooks/useConsoleSession";
import { currentUserId } from "../api/client";

const CONTEXT_KEY = "console:context";
const codeKey = (context) => `console:code:${context}`;

const RUBY_SAMPLE = `# Ctrl+Enter (Cmd+Enter) runs the snippet.
# Only what you print shows up — use p, pp or puts.
# Every run is a fresh process — nothing carries over.

p User.count
`;

const GO_SAMPLE = `// Ctrl+Enter (Cmd+Enter) builds and runs the program.
// Standard library only — the sandbox has no network.

package main

import "fmt"

func main() {
	fmt.Println("hello from Go")
}
`;

const CONTEXTS = [
  { id: "rails", label: "Rails", hint: "models + read-only database copy", language: "ruby", sample: RUBY_SAMPLE },
  { id: "ruby", label: "Plain Ruby", hint: "no Rails, no database", language: "ruby", sample: RUBY_SAMPLE },
  { id: "go", label: "Go", hint: "compiled and run, stdlib only", language: "go", sample: GO_SAMPLE }
];

const contextById = (id) => CONTEXTS.find((c) => c.id === id) || CONTEXTS[0];
const loadCode = (context) => localStorage.getItem(codeKey(context)) ?? contextById(context).sample;

const SESSION_PARAM = "session";
const sessionFromUrl = () => new URLSearchParams(window.location.search).get(SESSION_PARAM);
const writeSessionToUrl = (token) => {
  const url = new URL(window.location.href);
  if (token) url.searchParams.set(SESSION_PARAM, token);
  else url.searchParams.delete(SESSION_PARAM);
  window.history.replaceState(null, "", url);
};

// Server-side wall clock: process start-up (fork or spawn) plus the snippet itself.
const formatDuration = (ms) => (ms >= 1000 ? `${(ms / 1000).toFixed(2)} s` : `${ms} ms`);

const errorText = (data, status) => {
  const detail = data?.error || data?.errors;
  return typeof detail === "string" ? detail : detail ? JSON.stringify(detail) : `HTTP ${status}`;
};

export default function Console() {
  const [context, setContext] = useState(() => contextById(localStorage.getItem(CONTEXT_KEY)).id);
  const [code, setCode] = useState(() => loadCode(context));
  const [result, setResult] = useState(null);
  const [running, setRunning] = useState(false);
  const [session, setSession] = useState(sessionFromUrl);
  const [sessionError, setSessionError] = useState(null);
  const [split, setSplit] = useState(55); // % of the width taken by the editor
  const panes = useRef(null);
  const dragging = useRef(false);

  const shared = useConsoleSession(session, {
    onState: ({ code: remoteCode, context: remoteContext, by }) => {
      if (by === currentUserId()) return;
      setContext(remoteContext);
      setCode(remoteCode);
    },
    onRunning: ({ by }) => {
      if (by !== currentUserId()) setRunning(true);
    },
    onResult: (remoteResult) => {
      setResult(remoteResult);
      setRunning(false);
    },
    selfId: currentUserId()
  });

  useEffect(() => {
    if (session) return;
    localStorage.setItem(codeKey(context), code);
  }, [code, context, session]);
  useEffect(() => localStorage.setItem(CONTEXT_KEY, context), [context]);

  useEffect(() => {
    if (!session) return;
    fetchSession(session)
      .then((state) => {
        setContext(state.context);
        setCode(state.code);
        setResult(state.result);
        setSessionError(null);
      })
      .catch(() => {
        setSessionError("session not found");
        setSession(null);
        writeSessionToUrl(null);
      });
  }, [session]);

  const changeCode = (next) => {
    setCode(next);
    if (session) shared.pushState(next, context);
  };

  // Each context keeps its own draft: switching Ruby → Go must not leave Ruby code in a Go editor.
  // In a shared session the snippet belongs to everyone, so it stays as it is.
  const switchContext = (next) => {
    if (next === context) return;
    setContext(next);
    setResult(null);
    if (session) {
      shared.pushState(code, next);
    } else {
      setCode(loadCode(next));
    }
  };

  const share = async () => {
    const state = await createSession(code, context);
    setSession(state.token);
    writeSessionToUrl(state.token);
  };

  const leave = () => {
    setSession(null);
    writeSessionToUrl(null);
  };

  const copyLink = () => navigator.clipboard?.writeText(window.location.href);

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
    if (session) shared.announceRun();
    try {
      setResult(await runCode(code, context, session));
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
              onClick={() => switchContext(c.id)}
              title={c.hint}
            >
              {c.label}
            </button>
          ))}
        </div>

        <button className="ghost" onClick={() => setResult(null)}>
          Clear output
        </button>

        <div className="console-share">
          {session ? (
            <>
              <span className={shared.connected ? "live on" : "live"}>
                {shared.connected ? `● live · ${shared.participants}` : "○ connecting"}
              </span>
              <button className="ghost" onClick={copyLink} title="Anyone with the link edits and runs the same snippet">
                Copy link
              </button>
              <button className="ghost" onClick={leave}>
                Leave
              </button>
            </>
          ) : (
            <button className="ghost" onClick={share} title="Create a shared session and put its link in the URL">
              Share
            </button>
          )}
          {sessionError && <span className="live">{sessionError}</span>}
        </div>
      </div>

      <div className="console-panes" ref={panes}>
        <div className="console-pane" style={{ width: `${split}%` }}>
          <CodeEditor
            value={code}
            onChange={changeCode}
            language={contextById(context).language}
            cursors={session ? shared.cursors : undefined}
            onCursor={session ? shared.pushCursor : undefined}
          />
        </div>

        <div className="console-divider" onMouseDown={() => (dragging.current = true)} />

        <div className="console-pane console-result" style={{ width: `${100 - split}%` }}>
          <Output result={result} running={running} />

          {result && !running && (
            <div className="console-timing">
              ran in {formatDuration(result.duration_ms)} · {result.context}
              {result.by != null && result.by !== currentUserId() && " · by another participant"}
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
      {!output && !error && <pre className="out-dim">(nothing printed)</pre>}
    </>
  );
}
