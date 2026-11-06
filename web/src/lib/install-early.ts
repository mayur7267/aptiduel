// Chrome fires `beforeinstallprompt` once, early, often before React has
// hydrated. This tiny script (inlined by the layout) keeps the event, and
// lib/install.ts picks it up. See InstallCard.
export const EARLY_CAPTURE = "window.addEventListener('beforeinstallprompt',function(e){e.preventDefault();window.__installPrompt=e;});";
