import { useEffect, useRef, useState } from "react";
import ApiTokenPanel from "./ApiTokenPanel";
import TelegramLink from "./TelegramLink";

export default function SettingsPanel() {
  const [open, setOpen] = useState(false);
  const root = useRef(null);

  useEffect(() => {
    if (!open) return undefined;
    const close = (e) => root.current && !root.current.contains(e.target) && setOpen(false);
    document.addEventListener("mousedown", close);
    return () => document.removeEventListener("mousedown", close);
  }, [open]);

  return (
    <div className="digest" ref={root}>
      <button className="digest-btn" onClick={() => setOpen((v) => !v)} title="API token and notifications">⚙</button>
      {open && (
        <div className="digest-panel settings-panel">
          <section>
            <h4>API token for assistants</h4>
            <ApiTokenPanel />
          </section>
          <section>
            <h4>Telegram notifications</h4>
            <TelegramLink />
          </section>
        </div>
      )}
    </div>
  );
}
