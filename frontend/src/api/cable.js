import { createConsumer } from "@rails/actioncable";
import { API_BASE } from "../config";
import { getToken } from "./client";

// Browsers cannot set headers on a WebSocket, so the JWT travels as a query parameter.
const cableUrl = () => `${API_BASE.replace(/^http/, "ws").replace(/\/api\/v1$/, "")}/cable?token=${getToken()}`;

let consumer;
export const cable = () => (consumer ||= createConsumer(cableUrl()));
