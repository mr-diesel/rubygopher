import { useEffect, useRef, useState } from "react";
import { cable } from "../api/cable";

const CHANNEL = "Playground::Channels::ConsoleSessionChannel";
const DEBOUNCE_MS = 150;
const CURSOR_THROTTLE_MS = 100;

// Keeps one editor in sync with a shared session. Last write wins: whatever the
// server relays replaces the local state, and local edits are pushed debounced.
export function useConsoleSession(token, { onState, onRunning, onResult, selfId }) {
  const subscription = useRef(null);
  const timer = useRef(null);
  const cursorTimer = useRef(null);
  const handlers = useRef({ onState, onRunning, onResult });
  const [connected, setConnected] = useState(false);
  const [participants, setParticipants] = useState(0);
  const [cursors, setCursors] = useState({});
  handlers.current = { onState, onRunning, onResult };

  useEffect(() => {
    if (!token) return undefined;

    subscription.current = cable().subscriptions.create(
      { channel: CHANNEL, token },
      {
        connected: () => setConnected(true),
        disconnected: () => setConnected(false),
        rejected: () => setConnected(false),
        received: (message) => {
          if (message.type === "state") {
            if (message.participants != null) setParticipants(message.participants);
            handlers.current.onState(message);
          }
          if (message.type === "running") handlers.current.onRunning(message);
          if (message.type === "result") handlers.current.onResult(message.result);
          if (message.type === "presence") {
            setParticipants(message.participants);
            if (message.left != null) setCursors((prev) => Object.fromEntries(Object.entries(prev).filter(([id]) => Number(id) !== message.left)));
          }
          if (message.type === "cursor" && message.by !== selfId) {
            setCursors((prev) => ({ ...prev, [message.by]: { by: message.by, name: message.name, pos: message.pos } }));
          }
        }
      }
    );

    return () => {
      clearTimeout(timer.current);
      clearTimeout(cursorTimer.current);
      subscription.current?.unsubscribe();
      subscription.current = null;
      setConnected(false);
      setParticipants(0);
      setCursors({});
    };
  }, [token, selfId]);

  const pushState = (code, context) => {
    clearTimeout(timer.current);
    timer.current = setTimeout(() => subscription.current?.perform("update", { code, context }), DEBOUNCE_MS);
  };

  const announceRun = () => subscription.current?.perform("running", {});

  const pushCursor = (pos) => {
    if (cursorTimer.current) return;
    cursorTimer.current = setTimeout(() => {
      cursorTimer.current = null;
      subscription.current?.perform("cursor", { pos });
    }, CURSOR_THROTTLE_MS);
  };

  return { connected, participants, cursors, pushState, announceRun, pushCursor };
}
