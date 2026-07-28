import React from "react";
import { createRoot } from "react-dom/client";
import "./styles.css";

function App() {
  return (
    <main className="app-shell">
      <h1>react-app</h1>
      <p>Local cloud dev platform React starter.</p>
      <dl>
        <div>
          <dt>Status</dt>
          <dd>Ready</dd>
        </div>
        <div>
          <dt>Registry</dt>
          <dd>localhost:5000/react-app:local</dd>
        </div>
      </dl>
    </main>
  );
}

createRoot(document.getElementById("root")).render(<App />);

