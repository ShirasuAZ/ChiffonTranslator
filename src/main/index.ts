import { app, BrowserWindow, ipcMain, desktopCapturer, systemPreferences, session, Tray, Menu, nativeImage } from 'electron'
import * as path from 'path'
import * as fs from 'fs'

// Enable Chromium audio loopback feature flags — MUST be before app.whenReady()
const loopbackFeatures = [
  'MacLoopbackAudioForScreenShare',
  'MacSckSystemAudioLoopbackOverride',
  'PulseaudioLoopbackForScreenShare',
]
const existingFeatures = app.commandLine.getSwitchValue('enable-features')
if (existingFeatures) {
  app.commandLine.removeSwitch('enable-features')
  app.commandLine.appendSwitch('enable-features', [...existingFeatures.split(','), ...loopbackFeatures].join(','))
} else {
  app.commandLine.appendSwitch('enable-features', loopbackFeatures.join(','))
}

let mainWindow: BrowserWindow | null = null
let overlayWindow: BrowserWindow | null = null
let tray: Tray | null = null

const isDev = !app.isPackaged

// Settings persistence
interface AppSettings {
  sourceLang: string
  targetLang: string
  overlayOpacity: number
  showOverlay: boolean
}

const defaultSettings: AppSettings = {
  sourceLang: 'en',
  targetLang: 'zh',
  overlayOpacity: 0.7,
  showOverlay: false,
}

function getSettingsPath(): string {
  return path.join(app.getPath('userData'), 'settings.json')
}

function loadSettings(): AppSettings {
  try {
    const data = fs.readFileSync(getSettingsPath(), 'utf-8')
    return { ...defaultSettings, ...JSON.parse(data) }
  } catch {
    return { ...defaultSettings }
  }
}

function saveSettings(settings: Partial<AppSettings>): void {
  const current = loadSettings()
  const merged = { ...current, ...settings }
  fs.writeFileSync(getSettingsPath(), JSON.stringify(merged, null, 2))
}

function getIconPath(): string {
  if (isDev) {
    return path.join(__dirname, '..', '..', 'build', 'icon.png')
  }
  return path.join(process.resourcesPath, 'icon.png')
}

function getTrayIconPath(): string {
  if (isDev) {
    return path.join(__dirname, '..', '..', 'resources', 'tray-icon.png')
  }
  return path.join(process.resourcesPath, 'tray-icon.png')
}

function createMainWindow() {
  mainWindow = new BrowserWindow({
    width: 480,
    height: 600,
    resizable: true,
    frame: true,
    icon: getIconPath(),
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
    },
  })

  if (isDev) {
    mainWindow.loadURL('http://localhost:5173')
    mainWindow.webContents.openDevTools({ mode: 'detach' })
  } else {
    mainWindow.loadFile(path.join(__dirname, '..', 'renderer', 'index.html'))
  }

  mainWindow.on('closed', () => {
    mainWindow = null
    overlayWindow?.close()
  })
}

function createOverlayWindow() {
  if (overlayWindow) {
    overlayWindow.focus()
    return
  }

  overlayWindow = new BrowserWindow({
    width: 600,
    height: 160,
    alwaysOnTop: true,
    frame: false,
    transparent: true,
    resizable: true,
    skipTaskbar: true,
    hasShadow: false,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
    },
  })

  // Position at bottom center of screen
  const { screen } = require('electron')
  const display = screen.getPrimaryDisplay()
  const { width, height } = display.workAreaSize
  overlayWindow.setPosition(
    Math.floor((width - 600) / 2),
    height - 180
  )

  if (isDev) {
    overlayWindow.loadURL('http://localhost:5173/#/overlay')
  } else {
    overlayWindow.loadFile(path.join(__dirname, '..', 'renderer', 'index.html'), {
      hash: '/overlay',
    })
  }

  overlayWindow.setIgnoreMouseEvents(false)

  // Apply saved opacity immediately
  const settings = loadSettings()
  overlayWindow.setOpacity(Math.max(0.1, Math.min(1, settings.overlayOpacity)))

  overlayWindow.on('closed', () => {
    overlayWindow = null
  })
}

// IPC handlers
ipcMain.handle('get-sources', async () => {
  const sources = await desktopCapturer.getSources({
    types: ['screen', 'window'],
    thumbnailSize: { width: 0, height: 0 },
  })
  return sources.map(s => ({ id: s.id, name: s.name }))
})

ipcMain.on('open-overlay', () => {
  createOverlayWindow()
})

ipcMain.on('close-overlay', () => {
  overlayWindow?.close()
})

ipcMain.on('subtitle-update', (_event, data) => {
  overlayWindow?.webContents.send('subtitle-update', data)
})

ipcMain.on('set-overlay-opacity', (_event, opacity: number) => {
  const clamped = Math.max(0.1, Math.min(1, opacity))
  overlayWindow?.setOpacity(clamped)
  saveSettings({ overlayOpacity: clamped })
})

ipcMain.handle('get-settings', () => {
  return loadSettings()
})

ipcMain.handle('get-screen-permission', () => {
  if (process.platform === 'darwin') {
    return systemPreferences.getMediaAccessStatus('screen')
  }
  return 'granted'
})

ipcMain.on('save-settings', (_event, settings: Partial<AppSettings>) => {
  saveSettings(settings)
})

app.whenReady().then(async () => {
  // Check screen recording permission on macOS
  if (process.platform === 'darwin') {
    const screenStatus = systemPreferences.getMediaAccessStatus('screen')
    console.log('Screen recording permission:', screenStatus)
    if (screenStatus !== 'granted') {
      console.warn('Screen recording permission not granted! Audio loopback will not work.')
      console.warn('Go to: System Settings > Privacy & Security > Screen & System Audio Recording')
    }
  }

  // Handle getDisplayMedia requests — auto-grant with loopback audio
  session.defaultSession.setDisplayMediaRequestHandler((_request, callback) => {
    desktopCapturer.getSources({ types: ['screen'] }).then((sources) => {
      if (sources.length > 0) {
        console.log('Display media handler: granting screen', sources[0].name, 'with loopback audio')
        callback({ video: sources[0], audio: 'loopback' })
      } else {
        console.error('No screen sources found')
        callback({})
      }
    }).catch((err) => {
      console.error('Error getting sources:', err)
      callback({})
    })
  })

  // Listen for renderer crashes
  app.on('render-process-gone', (_event, _webContents, details) => {
    console.error('Renderer crashed:', details.reason, details.exitCode)
  })

  // Create tray icon
  const trayIcon = nativeImage.createFromPath(getTrayIconPath())
  tray = new Tray(trayIcon.resize({ width: 16, height: 16 }))
  tray.setToolTip('ChiffonTranslator')
  const contextMenu = Menu.buildFromTemplate([
    { label: '显示主窗口', click: () => mainWindow?.show() || createMainWindow() },
    { label: '退出', click: () => app.quit() },
  ])
  tray.setContextMenu(contextMenu)
  tray.on('click', () => mainWindow?.show() || createMainWindow())

  createMainWindow()

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createMainWindow()
    }
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
  }
})
