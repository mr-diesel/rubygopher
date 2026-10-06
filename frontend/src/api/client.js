import { API_BASE } from "../config";

const TOKEN_KEY = "token";

export const getToken = () => localStorage.getItem(TOKEN_KEY);
export const setToken = (t) => localStorage.setItem(TOKEN_KEY, t);
export const clearToken = () => localStorage.removeItem(TOKEN_KEY);

// The JWT's `sub` claim is the user id; decoding the payload needs no secret.
export const currentUserId = () => {
  try {
    return Number(JSON.parse(atob(getToken().split(".")[1].replace(/-/g, "+").replace(/_/g, "/"))).sub);
  } catch {
    return null;
  }
};

export async function request(path, { method = "GET", body } = {}) {
  const headers = { "Content-Type": "application/json" };
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (res.status === 204) return null;

  const data = await res.json().catch(() => null);
  if (!res.ok) throw { status: res.status, data };
  return data;
}
