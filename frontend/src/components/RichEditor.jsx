import { useEditor, EditorContent } from "@tiptap/react";
import { extensions, emptyDoc } from "../lib/editor";

export default function RichEditor({ value, onChange }) {
  const editor = useEditor({
    extensions,
    content: value || emptyDoc,
    onUpdate: ({ editor }) => onChange(editor.getJSON())
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
        {btn("B", editor.isActive("bold"), () => editor.chain().focus().toggleBold().run())}
        {btn("i", editor.isActive("italic"), () => editor.chain().focus().toggleItalic().run())}
        {btn("Text", editor.isActive("paragraph"), () => editor.chain().focus().setParagraph().run())}
        {btn("</> Code", editor.isActive("codeBlock"), () => editor.chain().focus().toggleCodeBlock().run())}
        {btn("• List", editor.isActive("bulletList"), () => editor.chain().focus().toggleBulletList().run())}
      </div>
      <EditorContent editor={editor} />
    </div>
  );
}
