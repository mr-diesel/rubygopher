import CodeMirror from "@uiw/react-codemirror";
import { StreamLanguage } from "@codemirror/language";
import { ruby } from "@codemirror/legacy-modes/mode/ruby";
import { go } from "@codemirror/legacy-modes/mode/go";

function extensionsFor(language) {
  if (language === "ruby") return [StreamLanguage.define(ruby)];
  if (language === "go") return [StreamLanguage.define(go)];
  return [];
}

export default function CodeEditor({ value, language, editable = false, onChange }) {
  return (
    <CodeMirror
      value={value || ""}
      editable={editable}
      extensions={extensionsFor(language)}
      onChange={onChange}
      basicSetup={{ lineNumbers: true, tabSize: 2, indentOnInput: true }}
    />
  );
}
