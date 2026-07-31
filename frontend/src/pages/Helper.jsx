import { useEffect, useMemo, useState } from "react";
import { DndContext, closestCenter } from "@dnd-kit/core";
import { SortableContext, arrayMove, useSortable, verticalListSortingStrategy } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import * as api from "../api/questions";
import * as catApi from "../api/categories";
import CodeEditor from "../components/CodeEditor";

const emptyDraft = { label: "", question: "", answer: "", code: "", language: "ruby", category: "" };
const byPosition = (a, b) => a.position - b.position;

function SortableRow({ id, active, onClick, children }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id });
  const style = { transform: CSS.Transform.toString(transform), transition, opacity: isDragging ? 0.5 : 1 };

  return (
    <div className="sortable-row" ref={setNodeRef} style={style}>
      <button className={active ? "active" : ""} onClick={onClick}>
        {children}
      </button>
      <span className="drag-handle" {...attributes} {...listeners} title="Drag to reorder">
        ⠿
      </span>
    </div>
  );
}

export default function Helper() {
  const [questions, setQuestions] = useState([]);
  const [categories, setCategories] = useState([]);
  const [category, setCategory] = useState(null);
  const [selected, setSelected] = useState(null);
  const [mode, setMode] = useState(null); // null | "create" | "edit"
  const [draft, setDraft] = useState(emptyDraft);

  const pick = (q) => {
    setMode(null);
    setSelected(q);
  };

  const load = async (keepCategory, keepQuestionId) => {
    const [qs, cats] = await Promise.all([api.listQuestions(), catApi.listCategories()]);
    setQuestions(qs);
    setCategories(cats);

    const cat = keepCategory && cats.includes(keepCategory) ? keepCategory : cats[0] || null;
    setCategory(cat);

    const inCat = qs.filter((q) => q.category === cat).sort(byPosition);
    pick(inCat.find((q) => q.id === keepQuestionId) || inCat[0] || null);
  };

  useEffect(() => {
    load();
  }, []);

  const current = useMemo(
    () => questions.filter((q) => q.category === category).sort(byPosition),
    [questions, category]
  );

  const selectCategory = (cat) => {
    setMode(null);
    setCategory(cat);
    const inCat = questions.filter((q) => q.category === cat).sort(byPosition);
    pick(inCat[0] || null);
  };

  const onCategoryDragEnd = async ({ active, over }) => {
    if (!over || active.id === over.id) return;
    const reordered = arrayMove(categories, categories.indexOf(active.id), categories.indexOf(over.id));
    setCategories(reordered);
    await catApi.reorderCategories(reordered);
  };

  const onQuestionDragEnd = async ({ active, over }) => {
    if (!over || active.id === over.id) return;
    const ids = current.map((q) => q.id);
    const reordered = arrayMove(ids, ids.indexOf(active.id), ids.indexOf(over.id));
    setQuestions((qs) =>
      qs.map((q) => (q.category === category ? { ...q, position: reordered.indexOf(q.id) } : q))
    );
    await api.reorderQuestions(reordered);
  };

  const remove = async () => {
    if (!window.confirm(`Delete "${selected.label}"? This can't be undone.`)) return;
    await api.deleteQuestion(selected.id);
    load(category);
  };

  const hide = async () => {
    if (!window.confirm(`Hide "${selected.label}" from your list?`)) return;
    await api.hideQuestion(selected.id);
    load(category);
  };

  const startCreate = () => {
    setSelected(null);
    setDraft(emptyDraft);
    setMode("create");
  };

  const startEdit = () => {
    setDraft({
      label: selected.label,
      category: selected.category,
      question: selected.question,
      answer: selected.answer || "",
      code: selected.code || "",
      language: selected.language || ""
    });
    setMode("edit");
  };

  const submitForm = async (e) => {
    e.preventDefault();
    const payload = { ...draft, category: draft.category || "General" };
    const q = mode === "edit" ? await api.updateQuestion(selected.id, payload) : await api.createQuestion(payload);
    setMode(null);
    load(q.category, q.id);
  };

  return (
    <div className="helper">
      <aside className="cat-col">
        <DndContext collisionDetection={closestCenter} onDragEnd={onCategoryDragEnd}>
          <SortableContext items={categories} strategy={verticalListSortingStrategy}>
            {categories.map((c) => (
              <SortableRow key={c} id={c} active={c === category} onClick={() => selectCategory(c)}>
                {c}
              </SortableRow>
            ))}
          </SortableContext>
        </DndContext>
      </aside>

      <aside className="q-col">
        <DndContext collisionDetection={closestCenter} onDragEnd={onQuestionDragEnd}>
          <SortableContext items={current.map((q) => q.id)} strategy={verticalListSortingStrategy}>
            {current.map((q) => (
              <SortableRow key={q.id} id={q.id} active={selected?.id === q.id && !mode} onClick={() => pick(q)}>
                {q.label}
              </SortableRow>
            ))}
          </SortableContext>
        </DndContext>
        <button className="new-btn" onClick={startCreate}>
          + New
        </button>
      </aside>

      <section className="helper-main">
        {mode ? (
          <form className="q-form" onSubmit={submitForm}>
            <h2>{mode === "edit" ? "Edit question" : "New question"}</h2>
            <input
              placeholder="Label (button name)"
              value={draft.label}
              onChange={(e) => setDraft({ ...draft, label: e.target.value })}
              required
            />
            <input
              placeholder="Category (Ruby, Rails, Go, ...)"
              value={draft.category}
              onChange={(e) => setDraft({ ...draft, category: e.target.value })}
            />
            <textarea
              placeholder="Question"
              value={draft.question}
              onChange={(e) => setDraft({ ...draft, question: e.target.value })}
              required
            />
            <textarea
              placeholder="Answer"
              value={draft.answer}
              onChange={(e) => setDraft({ ...draft, answer: e.target.value })}
            />
            <input
              placeholder="Language (ruby, go, ...)"
              value={draft.language}
              onChange={(e) => setDraft({ ...draft, language: e.target.value })}
            />
            <CodeEditor
              value={draft.code}
              language={draft.language}
              editable
              onChange={(v) => setDraft({ ...draft, code: v })}
            />
            <div className="form-actions">
              <button type="submit">{mode === "edit" ? "Save" : "Create"}</button>
              <button type="button" className="ghost" onClick={() => setMode(null)}>
                Cancel
              </button>
            </div>
          </form>
        ) : selected ? (
          <>
            <div className="q-head">
              <h2>{selected.question}</h2>
              {selected.default && <span className="badge">default</span>}
            </div>
            {selected.answer && <p className="answer">{selected.answer}</p>}
            <CodeEditor value={selected.code} language={selected.language} editable={false} />
            <div className="q-actions">
              {selected.editable && <button onClick={startEdit}>Edit</button>}
              {selected.editable && (
                <button className="danger" onClick={remove}>
                  Delete
                </button>
              )}
              {selected.default && (
                <button className="danger" onClick={hide}>
                  Hide
                </button>
              )}
            </div>
          </>
        ) : (
          <p>No questions in this category yet — add your own.</p>
        )}
      </section>
    </div>
  );
}
