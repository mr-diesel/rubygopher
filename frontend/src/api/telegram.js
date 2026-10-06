import { request } from "./client";

export const telegramStatus = () => request("/me/telegram");
export const startTelegramLink = () => request("/me/telegram/link", { method: "POST" });
export const unlinkTelegram = () => request("/me/telegram", { method: "DELETE" });
