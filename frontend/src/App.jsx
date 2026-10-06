import { useState } from "react";
import { useAuth } from "./hooks/useAuth";
import Login from "./pages/Login";
import Tracker from "./pages/Tracker";
import Helper from "./pages/Helper";
import Console from "./pages/Console";
import DigestBadge from "./components/DigestBadge";
import { useDigest } from "./hooks/useDigest";

const TAB_KEY = "tab";

const TABS = [
  { id: "tracker", label: "Tracker", render: () => <Tracker /> },
  { id: "helper", label: "Interview Helper", render: () => <Helper /> },
  { id: "console", label: "Live console", render: () => <Console /> }
];

export default function App() {
  const auth = useAuth();
  const [tab, setTab] = useState(() => localStorage.getItem(TAB_KEY) || TABS[0].id);

  if (!auth.authed) return <Login auth={auth} />;

  return <Shell auth={auth} tab={tab} setTab={setTab} />;
}

// Split from App so the digest polling only starts once the user is signed in.
function Shell({ auth, tab, setTab }) {
  const { digest, refresh } = useDigest();

  const select = (id) => {
    setTab(id);
    localStorage.setItem(TAB_KEY, id);
  };

  const active = TABS.find((t) => t.id === tab) || TABS[0];

  return (
    <div className="app">
      <header className="app-header">
        <strong>RubyGopher</strong>

        <nav className="tabs segmented">
          {TABS.map((t) => (
            <button key={t.id} className={t.id === active.id ? "active" : ""} onClick={() => select(t.id)}>
              {t.label}
            </button>
          ))}
        </nav>

        <DigestBadge digest={digest} onChange={refresh} />

        <button className="logout" onClick={auth.logout}>
          Logout
        </button>
      </header>

      {active.render()}
    </div>
  );
}
