import { useCallback, useEffect, useState } from "react";
import { fetchDigest } from "../api/digest";

const POLL_MS = 60_000;

// Polled, not pushed: a minute of staleness is fine for reminders, and it keeps
// the header independent of the WebSocket.
export function useDigest() {
  const [digest, setDigest] = useState(null);

  const refresh = useCallback(() => fetchDigest().then(setDigest).catch(() => {}), []);

  useEffect(() => {
    refresh();
    const timer = setInterval(refresh, POLL_MS);
    const onFocus = () => document.visibilityState === "visible" && refresh();
    document.addEventListener("visibilitychange", onFocus);
    return () => {
      clearInterval(timer);
      document.removeEventListener("visibilitychange", onFocus);
    };
  }, [refresh]);

  return { digest, refresh };
}
