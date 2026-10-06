import { useCallback, useEffect, useState } from "react";
import * as api from "../api/tracker";

// One hook per list kind: the two resources share the shape (list, select, refresh).
export function useTrackerList(kind, status) {
  const [items, setItems] = useState([]);
  const [selectedId, setSelectedId] = useState(null);
  const [detail, setDetail] = useState(null);
  const [loading, setLoading] = useState(true);

  const list = kind === "applications" ? api.listApplications : api.listOutreaches;
  const get = kind === "applications" ? api.getApplication : api.getOutreach;

  const refresh = useCallback(async () => {
    setLoading(true);
    try {
      setItems(await list({ status }));
    } finally {
      setLoading(false);
    }
  }, [list, status]);

  const select = useCallback(
    async (id) => {
      setSelectedId(id);
      setDetail(id == null ? null : await get(id));
    },
    [get]
  );

  useEffect(() => {
    refresh();
  }, [refresh]);

  useEffect(() => {
    setSelectedId(null);
    setDetail(null);
  }, [kind]);

  const reload = async (id = selectedId) => {
    await refresh();
    if (id != null) await select(id);
  };

  return { items, loading, selectedId, detail, select, reload };
}
