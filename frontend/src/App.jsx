import { useAuth } from "./hooks/useAuth";
import Login from "./pages/Login";

export default function App() {
  const auth = useAuth();

  if (!auth.authed) return <Login auth={auth} />;

  return (
    <div className="app">
      <header className="app-header">
        <strong>RubyGopher</strong>
        <button onClick={auth.logout}>Logout</button>
      </header>
      <main>
        <p>You are signed in. The interview helper will appear here (stage 3).</p>
      </main>
    </div>
  );
}
