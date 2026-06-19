import "./styles.css";
import { NEXIUM_CONNECT_URL } from "./config";

const frame = document.querySelector<HTMLIFrameElement>("#nexiumFrame");
const openButton = document.querySelector<HTMLButtonElement>("#openApp");
const reloadButton = document.querySelector<HTMLButtonElement>("#reloadApp");
const status = document.querySelector<HTMLParagraphElement>("#status");

function setStatus(message: string): void {
  if (status) status.textContent = message;
}

function loadNexium(): void {
  if (!frame) return;
  frame.src = NEXIUM_CONNECT_URL;
  frame.classList.add("is-visible");
  setStatus(`Loaded: ${NEXIUM_CONNECT_URL}`);
}

openButton?.addEventListener("click", loadNexium);
reloadButton?.addEventListener("click", () => {
  if (!frame?.src) {
    loadNexium();
    return;
  }
  frame.src = frame.src;
  setStatus("Reloading Nexium Connect...");
});

window.addEventListener("DOMContentLoaded", loadNexium);
