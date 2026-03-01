/// <reference types="vite/client" />

interface ElectronAPI {
  getSources: () => Promise<{ id: string; name: string }[]>
  openOverlay: () => void
  closeOverlay: () => void
  setOverlayOpacity: (opacity: number) => void
  sendSubtitleUpdate: (data: { original: string; translated: string }) => void
  onSubtitleUpdate: (callback: (data: { original: string; translated: string }) => void) => () => void
  getSettings: () => Promise<{ sourceLang: string; targetLang: string; overlayOpacity: number; showOverlay: boolean }>
  saveSettings: (settings: Partial<{ sourceLang: string; targetLang: string; overlayOpacity: number; showOverlay: boolean }>) => void
  getScreenPermission: () => Promise<string>
}

interface Window {
  electronAPI: ElectronAPI
}
