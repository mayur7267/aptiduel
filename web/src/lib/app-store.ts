// The iPhone app on the App Store. The layout's smart banner, the home
// page card, the sidebar and the help page all link here.
export const APP_STORE_ID = "6828983597";
export const APP_STORE_URL = `https://apps.apple.com/in/app/apticks-aptitude-test-duels/id${APP_STORE_ID}`;

// iPhones and iPads, including iPads that report a Mac (they have touch).
export function isAppleMobile() {
  return /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
}
