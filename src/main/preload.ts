import { contextBridge, ipcRenderer } from 'electron'

contextBridge.exposeInMainWorld('electronAPI', {
  getSources: () => ipcRenderer.invoke('get-sources'),
  openOverlay: () => ipcRenderer.send('open-overlay'),
  closeOverlay: () => ipcRenderer.send('close-overlay'),
  setOverlayOpacity: (opacity: number) => ipcRenderer.send('set-overlay-opacity', opacity),
  sendSubtitleUpdate: (data: any) => ipcRenderer.send('subtitle-update', data),
  onSubtitleUpdate: (callback: (data: any) => void) => {
    ipcRenderer.on('subtitle-update', (_event, data) => callback(data))
    return () => ipcRenderer.removeAllListeners('subtitle-update')
  },
  getSettings: () => ipcRenderer.invoke('get-settings'),
  saveSettings: (settings: any) => ipcRenderer.send('save-settings', settings),
  getScreenPermission: () => ipcRenderer.invoke('get-screen-permission'),
})
