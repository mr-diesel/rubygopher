export const APPLICATION_STATUSES = ["applied", "viewed", "screening", "tech_interview", "offer", "rejected"];
export const OUTREACH_STATUSES = ["no_response", "talent_pool", "interview", "offer", "rejected"];
export const EVENT_TYPES = ["status_changed", "note_added", "interview_scheduled", "follow_up_sent"];

export const label = (value) => value.replaceAll("_", " ");

export const fmtDate = (iso) => (iso ? new Date(iso).toLocaleDateString() : "");
export const fmtDateTime = (iso) => (iso ? new Date(iso).toLocaleString([], { dateStyle: "short", timeStyle: "short" }) : "");

// <input type="datetime-local"> gives a local wall-clock string; the API wants ISO 8601.
export const toIso = (local) => (local ? new Date(local).toISOString() : undefined);

export const errorMessage = (e) => {
  const errors = e?.data?.errors;
  if (errors && typeof errors === "object") {
    return Object.entries(errors)
      .map(([field, messages]) => `${field === "null" || field === "" ? "" : `${field}: `}${[].concat(messages).join(", ")}`)
      .join("; ");
  }
  return e?.data?.error || `HTTP ${e?.status ?? "?"}`;
};
