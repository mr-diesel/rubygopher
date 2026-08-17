import { useEditor, EditorContent } from "@tiptap/react";
import { useEffect } from "react";
import { extensions } from "../lib/editor";

export default function RichContent({ content }) {
  const editor = useEditor({ editable: false, extensions, content: content || "" });

  useEffect(() => {
    if (editor && content) editor.commands.setContent(content);
  }, [editor, content]);

  if (!editor) return null;

  return <EditorContent editor={editor} className="rich-content" />;
}
