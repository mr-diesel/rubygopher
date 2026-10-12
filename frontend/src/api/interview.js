import { request } from "./client";

export const interviewPrompt = (applicationId) => request(`/interview/prompt${applicationId ? `?application_id=${applicationId}` : ""}`);
