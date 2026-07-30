import { useState } from "react";

export default function Login({ auth }) {
  const [mode, setMode] = useState("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [error, setError] = useState(null);

  const submit = async (e) => {
    e.preventDefault();
    setError(null);
    try {
      if (mode === "login") {
        await auth.login(email, password);
      } else {
        await auth.signup(email, password, name);
      }
    } catch (err) {
      setError(err?.data?.errors || err?.data?.error || "Something went wrong");
    }
  };

  return (
    <div className="auth-card">
      <h1>{mode === "login" ? "Sign in" : "Sign up"}</h1>
      <form onSubmit={submit}>
        {mode === "signup" && (
          <input placeholder="Name" value={name} onChange={(e) => setName(e.target.value)} />
        )}
        <input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />
        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
        />
        <button type="submit">{mode === "login" ? "Sign in" : "Sign up"}</button>
      </form>

      {error && <p className="error">{JSON.stringify(error)}</p>}

      <button className="link" onClick={() => setMode(mode === "login" ? "signup" : "login")}>
        {mode === "login" ? "Need an account? Sign up" : "Have an account? Sign in"}
      </button>
    </div>
  );
}
