// API base follows the host the page was opened from, so it works both on the
// laptop (localhost) and from another device on the LAN (laptop's IP).
const host = window.location.hostname;

export const API_BASE = import.meta.env.VITE_API_BASE || `http://${host}:3000/api/v1`;
