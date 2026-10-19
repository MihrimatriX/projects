import { loader } from "@monaco-editor/react";
import * as monaco from "monaco-editor";
import editorWorker from "monaco-editor/editor/editor.worker?worker";
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import "./styles/app.css";

self.MonacoEnvironment = {
  getWorker() {
    return new editorWorker();
  },
};

// Varsayılan olarak @monaco-editor/react Monaco'yu CDN'den (jsdelivr) indirir; çevrimdışı/exe'de
// diff editörü "Loading..." ekranında kalır. Paketlenmiş yerel kopyayı kullan.
loader.config({ monaco });

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
