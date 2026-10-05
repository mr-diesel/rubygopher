import { useEditor, EditorContent, useEditorState } from "@tiptap/react";
import { extensions, emptyDoc } from "../lib/editor";

export default function RichEditor({ value, onChange }) {
  const editor = useEditor({
    extensions,
    content: value || emptyDoc,
    onUpdate: ({ editor }) => onChange(editor.getJSON())
  });
  const active = useEditorState({
    editor,
    selector: ({ editor }) => ({
      bold: editor?.isActive("bold"),
      italic: editor?.isActive("italic"),
      paragraph: editor?.isActive("paragraph"),
      codeBlock: editor?.isActive("codeBlock"),
      bulletList: editor?.isActive("bulletList")
    })
  });

  if (!editor) return null;

  const btn = (label, isActive, action) => (
    <button type="button" className={isActive ? "on" : ""} onClick={() => action()}>
      {label}
    </button>
  );

  return (
    <div className="rich-editor">
      <div className="rich-toolbar">
        {btn("B", active.bold, () => editor.chain().focus().toggleBold().run())}
        {btn("i", active.italic, () => editor.chain().focus().toggleItalic().run())}
        {btn("Text", active.paragraph, () => editor.chain().focus().setParagraph().run())}
        {btn("</> Code", active.codeBlock, () => editor.chain().focus().toggleCodeBlock().run())}
        {btn("• List", active.bulletList, () => editor.chain().focus().toggleBulletList().run())}
      </div>
      <EditorContent editor={editor} />
    </div>
  );
}
