import { useEffect, useState } from "react";
import { startTelegramLink, telegramStatus, unlinkTelegram } from "../api/telegram";

// Lives in the digest panel: shows whether the bot is linked and hands out the deep link.
export default function TelegramLink() {
  const [state, setState] = useState(null);

  useEffect(() => {
    telegramStatus().then(setState).catch(() => {});
  }, []);

  if (!state) return null;

  const start = async () => setState(await startTelegramLink());
  const unlink = async () => {
    await unlinkTelegram();
    setState(await telegramStatus());
  };

  if (state.linked) {
    return (
      <div className="digest-row">
        <span>Telegram: connected</span>
        <button className="ghost" onClick={unlink}>Disconnect</button>
      </div>
    );
  }
  if (!state.bot) return <p className="dim">Telegram bot is not configured on the server.</p>;
  if (state.link_url) {
    return (
      <div className="digest-row">
        <span>
          Open the bot and press Start:
          <small><a href={state.link_url} target="_blank" rel="noreferrer">{state.link_url}</a></small>
        </span>
        <button className="ghost" onClick={() => telegramStatus().then(setState)}>Check</button>
      </div>
    );
  }
  return (
    <div className="digest-row">
      <span>Telegram: not connected</span>
      <button className="ghost" onClick={start}>Connect</button>
    </div>
  );
}
