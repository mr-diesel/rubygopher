import { useAuth } from "./hooks/useAuth";
import Login from "./pages/Login";
import Helper from "./pages/Helper";

export default function App() {
  const auth = useAuth();

  if (!auth.authed) return <Login auth={auth} />;

  return (
    <div className="app">
      <header className="app-header">
        <strong>RubyGopher — Interview Helper</strong>
        <button onClick={auth.logout}>Logout</button>
      </header>
      <Helper />
    </div>
  );
}
