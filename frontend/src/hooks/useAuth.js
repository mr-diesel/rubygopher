import { useState, useCallback } from "react";
import { request, setToken, clearToken, getToken } from "../api/client";

export function useAuth() {
  const [user, setUser] = useState(null);
  const [authed, setAuthed] = useState(Boolean(getToken()));

  const signup = useCallback(async (email, password, name) => {
    const data = await request("/signup", { method: "POST", body: { email, password, name } });
    setToken(data.token);
    setUser(data.user);
    setAuthed(true);
  }, []);

  const login = useCallback(async (email, password) => {
    const data = await request("/login", { method: "POST", body: { email, password } });
    setToken(data.token);
    setUser(data.user);
    setAuthed(true);
  }, []);

  const logout = useCallback(async () => {
    try {
      await request("/logout", { method: "DELETE" });
    } catch {
      // token already invalid — clear locally anyway
    }
    clearToken();
    setUser(null);
    setAuthed(false);
  }, []);

  return { user, authed, signup, login, logout };
}
