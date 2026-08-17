import StarterKit from "@tiptap/starter-kit";
import CodeBlockLowlight from "@tiptap/extension-code-block-lowlight";
import { Markdown } from "tiptap-markdown";
import { createLowlight } from "lowlight";
import ruby from "highlight.js/lib/languages/ruby";
import sql from "highlight.js/lib/languages/sql";
import go from "highlight.js/lib/languages/go";
import javascript from "highlight.js/lib/languages/javascript";

const lowlight = createLowlight();
lowlight.register({ ruby, sql, go, javascript });

export const extensions = [
  StarterKit.configure({ codeBlock: false }),
  CodeBlockLowlight.configure({ lowlight, defaultLanguage: "ruby" }),
  // Paste markdown → auto-convert to paragraphs + code blocks.
  Markdown.configure({ html: false, transformPastedText: true })
];

export const emptyDoc = { type: "doc", content: [{ type: "paragraph" }] };
