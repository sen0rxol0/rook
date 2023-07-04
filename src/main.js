const gui = require('gui'),path = require('path'),fs = require('fs'),{ execFile } = require('child_process');
const dapi = require("../device")
const productName = require('../package.json').build.productName
const envPath = new String(process.env.PATH),
strContains = (str, c) => (str.indexOf(c) !== -1);
const DEVICE_SEARCHING_INTERVAL = 3000,
WINDOW_WIDTH = 480,
WINDOW_HEIGHT = 640,
STYLES = {buttonDefault: {width: 128,marginTop: 16,marginBottom: 16},container: {width: '100%',flex: 1,flexDirection: 'column',alignItems: 'center',justifyContent: 'flex-start',padding: 16}
},
COLORS = (() => {
  if (gui.appearance.isDarkScheme()) {
    return {background:gui.Color.rgb(32, 32, 32),backgroundDarker:gui.Color.rgb(15, 15, 15),text:gui.Color.rgb(255, 255, 255)}
  }
  return {background:gui.Color.rgb(232, 232, 232),backgroundDarker:gui.Color.rgb(154, 154, 154),text:gui.Color.rgb(0, 0, 0)}
})();

if (!strContains(envPath, '/usr/local/bin:')) {
  process.env.PATH = `/usr/local/bin:${envPath.toString()}`
}

function appRootPath() {
  return path.resolve(process.execPath, '..')
}

function createContainer() {
    const container = gui.Container.create()
    container.setStyle(STYLES.container)
    container.setBackgroundColor(COLORS.background)
    return container
}

function initDeviceSearchInterval() {
  deviceInfo.search()
  setTimeout(() => {
    global.si = setInterval(() => {
      deviceInfo.search()
    }, DEVICE_SEARCHING_INTERVAL)
  }, DEVICE_SEARCHING_INTERVAL)
}

function clearDeviceSearchInterval() {
  clearInterval(global.si)
}

function getDeviceName(deviceId) {
  return deviceList[deviceId].name;
}

function updateLogs(log, error = false) {
  const callbk = (e) => {
    if (e) throw e
  }
  let logFile = error?'errors.log':'logs.log';
  logFile = fs.realpathSync(path.join(__dirname, '..', 'storage', 'logs', logFile))
  fs.open(logFile, (err, fd) => {
    if (err) {
      fs.writeFile(logFile, '', callbk)
    } else {
      fs.appendFile(logFile, `\n${log}\n`, callbk)
    }
  })
}

function showMessageBox(message, onResponse = undefined) {
  const mb = gui.MessageBox.create()
  mb.setText(message || "Something went wrong!")
  mb.addButton("OK", 0)
  mb.setDefaultResponse(0)

  if (onResponse) {
    onResponse(mb.runForWindow(mainWindow.window))
  } else {
    mb.runForWindow(mainWindow.window)
  }
}

function execCmd(file = '', args = [], opt = {}) {
  return new Promise((res, rej) => {
    execFile(file, args, opt, (err, stdout) => {
      if (err) {
        updateLogs(`exec ERROR: ${file} ${args}\n`, err)
        rej(err)
        return
      }
      updateLogs(`exec DONE: ${file} ${args}\n`)
      res(stdout)
    })
  })
}

function spawnScript(scriptFilename, terminal = true, onDone = null) {
  const scriptPath = fs.realpathSync(path.join(__dirname, '..', `scripts/${scriptFilename}`))
  const onSpawnError = (err) => {
    // console.error(err)
    showMessageBox("Error occurred!")
  },
  onSpawnDone = (res) => {
    if (onDone) {
      onDone()
    }
    // console.log(res)
    // showMessageBox("Done successfully!")
  };
  fs.chmod(scriptPath, 0o775, (err) => {
    if (err) throw err;
    if (terminal) {
      execCmd('open', ['-W', '-n', '-aTerminal', scriptPath]).then(onSpawnDone, onSpawnError)
    } else {
      execCmd(scriptPath).then(onSpawnDone, onSpawnError)
    }
  })
}

function onStartRestore() {
  const restoreLatest = gui.MenuItem.create("label")
  restoreErase = gui.MenuItem.create("label"),
  itemRestore = gui.MenuItem.create("submenu"),
  itemFutureRestore = gui.MenuItem.create("label");
  restoreLatest.setLabel('Restore to latest firmware')
  restoreLatest.onClick = () => {
    spawnScript('restore_device.sh')
  }
  restoreErase.setLabel('Erase restore to latest firmware')
  const itemRestoreSubmenu = gui.Menu.create([restoreLatest, restoreErase])
  itemRestore.setLabel('Choose a restore method')
  itemRestore.setSubmenu(itemRestoreSubmenu)
  itemFutureRestore.setLabel('Restore with futurerestore')
  itemFutureRestore.onClick = () => {

  }
  const menu = gui.Menu.create([itemRestore, itemFutureRestore])
  menu.popup()
}

function onExitRecovery() {
  spawnScript('exit_recovery.sh', false)
}

function onBootRamdisk() {

  if (dapi.startDevice() < 0) {
    showMessageBox("No device found in DFU Mode!")
    return false
  }

  clearDeviceSearchInterval()

  const rdskBootDone = () => {
    progressBar.setProgressValue(0, true)
    execCmd('bash', ['-c','iproxy 2222 22 > /dev/null 2>&1 &'], {shell: true}).then(() => {
      showMessageBox("SSH connect with password 'alpine':\n root@localhost -p2222", () => {
        // execCmd('sshpass /sbin/reboot')
        execCmd('killall', ['iproxy']).then(() => {
          progressBar.setProgressValue(0)
          initDeviceSearchInterval()
        })
      });
    })
  }

  const deviceDFUInfo = dapi.getInfo(),
  deviceId = `${deviceDFUInfo.product_type}_${deviceDFUInfo.hardware_model}`;

  const tmpDir = path.join('/tmp/', `${app.name}-rdsk_boot`),
  rdskBoot = () => {
    progressBar.setProgressValue(7)

    spawnScript('run_gaster.sh', false)
    setTimeout(() => {
      progressBar.setProgressValue(15)
      dapi.sendFile(path.join(tmpDir, 'ibss.img4'))
      progressBar.setProgressValue(20)
      setTimeout(() => {
        dapi.sendFile(path.join(tmpDir, 'ibec.img4'))

        if (strContains(deviceDFUInfo.cpid, "0x801")) {
          dapi.sendCommand("go")
        }

        progressBar.setProgressValue(25)
        setTimeout(() => {
          //@TODO: check if device booted iboot and reached recovery mode
          progressBar.setProgressValue(40)
          dapi.sendCommand("bootx")
          dapi.sendFile(path.join(tmpDir, 'bootlogo.img4'))
          dapi.sendCommand("setpicture 0")
          dapi.sendCommand("bgcolor 0 0 0")
          progressBar.setProgressValue(45)
          dapi.sendFile(path.join(tmpDir, 'dtree.img4'))
          dapi.sendCommand("devicetree")
          progressBar.setProgressValue(50)
          dapi.sendFile(path.join(tmpDir, 'ramdisk.img4'))
          dapi.sendCommand("ramdisk")
          progressBar.setProgressValue(75)
          dapi.sendFile(path.join(tmpDir, 'trustcache.img4'))
          dapi.sendCommand("firmware")
          progressBar.setProgressValue(85)
          dapi.sendFile(path.join(tmpDir, 'kcache.img4'))
          progressBar.setProgressValue(95)
          dapi.sendCommand("bootx")
          setTimeout(() => {
            progressBar.setProgressValue(100)
            rdskBootDone()
          }, 7000)
        }, 5000)
      }, 1000)
    }, 10000)
  };


  initBootRamdisk(deviceId).then((filepath) => {
    progressBar.setProgressValue(2)
    fs.rmdir(tmpDir, () => {
      fs.mkdir(tmpDir, () => {
        execCmd('tar', ['-C', `${tmpDir}`, '-xf', `${filepath}`]).then(() => {
          rdskBoot()
        })
      })
    })
  })
}

function initBootRamdisk(deviceId) {
  const rdskScriptPath = fs.realpathSync(path.join(__dirname, '..', 'scripts/custom_rd.sh')),
  rdskStoragePath = path.join(appRootPath(), 'res', 'resources', 'rdsk'),
  findRdskFile = () => {
    return new Promise((res, rej) => {
      let realpath = null
      setTimeout(() => {
        if (realpath === null) { rej() } else { res(realpath) }
      }, 2000)
      fs.readdir(rdskStoragePath, (err, rdskFiles) => {
        rdskFiles.forEach((rdskFile, i) => {
          if (strContains(rdskFile, deviceId)) {
            fs.realpath(`${rdskStoragePath}/${rdskFile}`, (err, path) => {
              realpath = path
            })
          }
        })
      })
    })
  };

  return new Promise((res, rej) => {
    const rdskWatch = fs.watch(path.join(appRootPath(), 'res', 'resources', 'rdsk'), (ev, filename) => {
      if (filename.endsWith(".tar.gz")) {
        rdskWatch.close()
        setTimeout(() => {
          findRdskFile().then(res)
        }, 25000)
      }
    })

    findRdskFile().then(res, () => {
      spawnScript('start_custom_rd.sh', true, () => {

      })
    })
  })
}

function onPwnDevice() {
  const exploitMessage = gui.MessageBox.create()
  exploitMessage.setText("Pick a checkm8 exploit to run.")
  exploitMessage.addButton("Run ipwndfu", 1)
  exploitMessage.addButton("Run gaster", 2)
  exploitMessage.addButton("Cancel", 0)
  exploitMessage.setDefaultResponse(0)
  const pwnDevice = (res) => {
    if (res === 1) {
      // spawnScript('run_ipwndfu.sh')
    } else if (res === 2) {
      spawnScript('run_gaster.sh')
    }
  }
  pwnDevice(exploitMessage.runForWindow(mainWindow.window))
}

function installRequiredLibraires() {
    return new Promise((res) => {

      const libsToCheck = ['brew', 'irecovery', 'idevicerestore'],
      installRequired = () => {
        const requiredLibsMessage = gui.MessageBox.create()
        requiredLibsMessage.setText("Required libraires not found!\nContinue to install.")
        requiredLibsMessage.addButton("Continue", 1)
        requiredLibsMessage.setDefaultResponse(1)
        requiredLibsMessage.runForWindow(mainWindow.window)
        const installingMessage = gui.MessageBox.create()
        installingMessage.setText("Please wait...")
        installingMessage.setInformativeText("Installing required libraires.")
        installingMessage.runForWindow(mainWindow.window)
        const libsInstalledFilePath = fs.realpathSync(path.join(__dirname, '..', 'storage', 'libs_installed'))
        fs.writeFile(libsInstalledFilePath, '', 'utf8', (err) => {
          if (err) throw err
          fs.watchFile(libsInstalledFilePath, (curr, prev) => {
            if (curr.size > prev.size) {
                fs.rm(libsInstalledFilePath, (err) => {
                  if (err) throw err
                })
                installingMessage.close()
                res()
            }
          })
          spawnScript('install_libs.sh')
        })
      };
      let isRequired = false
      for (let i = 0; i < libsToCheck.length; i++) {
        fs.stat(`/usr/local/bin/${libsToCheck[i]}`, (err, stats) => {
          if (!stats || !stats.isFile()) {
            installRequired()
            isRequired = true
          }
        })

        if (((i + 1) == libsToCheck.length) && !isRequired) {
          res()
        }
      }
    })
}

function onFirstRunSetup() {

  return new Promise((res, rej) => {

    installRequiredLibraires().then(() => {

      if (process.execPath.indexOf(`Applications/${productName}.app/`) > 0) {
        const appResourcesPath = path.join(appRootPath(), 'res', 'resources');

        fs.opendir(appResourcesPath, (err, dir) => {
          if (err) {
            spawnScript('setup_required.sh', true, () => {
              console.log("SETUP DONE")
              res()
            })
          } else {
            res()
          }
        })
      } else {
        res()
      }
    })

  })
}

class Controls {

    constructor() {
      this.container = createContainer()
      this.container.setStyle({ width: '100%', maxHeight: '256px', marginTop: 16, flex: 1, flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between' })

        // this.activateButton = gui.Button.create('Hacktivate')
        // this.activateButton.onClick = onStartActivate
        // this.activateButton.setStyle(STYLES.buttonDefault)
        // this.container.addChildView(this.activateButton)

        this.restoreButton = gui.Button.create('Restore')
        this.restoreButton.onClick = onStartRestore
        this.restoreButton.setStyle(STYLES.buttonDefault)
        this.container.addChildView(this.restoreButton)

      	this.pwnButton = gui.Button.create('pwn Device')
        this.pwnButton.onClick = onPwnDevice
        this.pwnButton.setStyle(STYLES.buttonDefault)
        this.container.addChildView(this.pwnButton)

      	this.bootRamdiskButton = gui.Button.create('SSH Ramdisk')
        this.bootRamdiskButton.onClick = onBootRamdisk
        this.bootRamdiskButton.setStyle(STYLES.buttonDefault)
        this.container.addChildView(this.bootRamdiskButton)

      	this.exitRecoveryButton = gui.Button.create('Exit recovery')
        this.exitRecoveryButton.onClick = onExitRecovery
        this.exitRecoveryButton.setStyle(STYLES.buttonDefault)
        this.container.addChildView(this.exitRecoveryButton)

        this.resetEnabled()
    }

    enableForRecovery() {
      this.restoreButton.setEnabled(true)
      this.exitRecoveryButton.setEnabled(true)
    }

    enableForDFU() {
      this.pwnButton.setEnabled(true)
      this.bootRamdiskButton.setEnabled(true)
      // this.ramdiskButton.setEnabled(true)
    }

    resetEnabled() {
      // this.activateButton.setEnabled(false)
      this.restoreButton.setEnabled(false)
      this.pwnButton.setEnabled(false)
      this.bootRamdiskButton.setEnabled(false)
      this.exitRecoveryButton.setEnabled(false)
    }
}

class ProgressBar {

	constructor() {
		this.progressBar = gui.ProgressBar.create()
    this.progressBar.setStyle({ minWidth: '100%', width: '100%' })
    this.setProgressValue(0)
		this.container = gui.Container.create()
		this.container.addChildView(this.progressBar)
	}

	setProgressValue(value, indeterminate = false) {
  	if (this.progressBar.isIndeterminate()) {
      this.progressBar.setIndeterminate(false)
  	}

  	if (indeterminate) {
      this.progressBar.setIndeterminate(indeterminate)
  	} else {
      this.progressBar.setValue(value)
  	}
  }
}

class DeviceInfo {
    constructor() {
	      const table = gui.Table.create()
        table.setStyle({ flex: 1 })
        this.tableModel = gui.SimpleTableModel.create(2)
        table.setModel(this.tableModel)
        table.addColumn('Mode')
        table.addColumn('Device')
        const group = gui.Group.create("")
        group.setContentView(table)
        group.setStyle({ flex: 1, width: '100%', maxHeight: '80px' })
      	this.deviceLabel = gui.Label.create('Please connect device to USB.')
        this.deviceLabel.setStyle({ minWidth: '100%' })
       	this.container = createContainer()
      	this.container.addChildView(this.deviceLabel)
      	this.container.addChildView(group)
    }

    search() {

      const writeDeviceInfo = (data) => {

        fs.writeFile(this.getFilePath(), data, 'utf8', (err) => {
          if (err) throw err
          this.loadData()
        })
      }

      execCmd('irecovery', ['-q']).then((stdout) => {
        if (!isDeviceConnected) {
          isDeviceConnected = true
          writeDeviceInfo(stdout)
        }
      }).catch(() => {
        if (isDeviceConnected) {
          isDeviceConnected = false
          this.clearData()
          controls.resetEnabled()
        }
      })
    }

    loadData() {
      const deviceInfo = {}

      const setData = () => {
        this.tableModel.addRow([deviceInfo.mode, `${getDeviceName(deviceInfo.productType)} (${deviceInfo.productType})`])
        this.deviceLabel.setText(`${deviceInfo.productType} connected in ${deviceInfo.mode} Mode.`)

        switch(deviceInfo.mode) {
          case 'DFU':
            controls.enableForDFU()
            break
          case 'Recovery':
            controls.enableForRecovery()
            break
        }
      }

      if (this.tableModel.getRowCount() === 0) {
        const deviceInfoFilePath = this.getFilePath();

        execCmd('grep', ['MODE:', deviceInfoFilePath]).then((stdoutMode) => {

          if (strContains(stdoutMode.toString(), "DFU")) { deviceInfo['mode'] = "DFU" } else { deviceInfo['mode'] = "Recovery" }

          execCmd('grep', ['PRODUCT:', deviceInfoFilePath]).then((stdoutProduct) => {
            deviceInfo['productType'] = stdoutProduct.toString().replace(`PRODUCT: `, '').replace(/\n/g, "")
            setData()
          })
        })
      }
    }

    clearData() {
      if (this.tableModel.getRowCount() > 0) {
        this.tableModel.removeRowAt(0)
        this.deviceLabel.setText('Please connect device to USB.')
      }
    }

    getFilePath() {
      return fs.realpathSync(path.join(__dirname, '..', 'storage', 'device_info'))
    }
}

class MainWindow {
  constructor() {
    this.window = gui.Window.create({})
    this.window.setTitle(productName)
    this.window.setContentSize({width: 340,height: 520})
    this.window.setMaximizable(false)
    this.window.setMinimizable(false)
    this.window.onClose = () => gui.MessageLoop.quit()
    this.window.center()
    this.window.activate()
  }

  setContentView() {
    this.container = createContainer()
    this.container.setStyle({ width: '100%' })
    const heading = gui.Container.create(),
    headingLabel = gui.Label.createWithAttributedText(gui.AttributedText.create(`Welcome to ${productName}`, { font: gui.Font.default().derive(0, 'bold', 'normal'), align: 'center', valign: 'center' }));
    headingLabel.setStyle({ height: '56px' })
    heading.addChildView(headingLabel)
    this.container.addChildView(heading)
   	this.container.addChildView(controls.container)

    // const helperContainer = gui.Container.create(),
    // helperButton = gui.Button.create("Enter DFU");
    // helperButton.onClick = () => {
    //   const winParent = new BrowserWindow({width: 400,height: 480,show: false,frame: false,resizable: false,minimizable: false, maximizable: false,movable: false,closable: false}),
    //   win = new BrowserWindow({parent: winParent,width: 400,height: 480,show: false,modal: true,webPreferences: {preload: path.join(__dirname, 'enter_dfu_preload.js')}})
    //   win.loadFile(path.join(__dirname, 'enter_dfu.html'))
    //   win.once('ready-to-show', () => {
    //     win.show()
    //   })
    //   ipcMain.on('close-enter-dfu', (event) => {
    //     winParent.destroy()
    //   })
    // }
    // helperContainer.setStyle({width:'100%',flexDirection:'row',padding: 16 })
    // helperContainer.addChildView(helperButton)
    // this.container.addChildView(helperContainer)

    // this.container.addChildView(this.createPicker())
    this.container.addChildView(deviceInfo.container)
  	this.container.addChildView(progressBar.container)
    this.window.setContentView(this.container)
  }
}

class Delegate {

    constructor() {
      if (process.platform === 'darwin') {
      }
      global.controls = new Controls()
      global.deviceInfo = new DeviceInfo()
      global.progressBar = new ProgressBar()
      global.mainWindow = new MainWindow()
    }

    ready() {
        onFirstRunSetup().then(() => {
          initDeviceSearchInterval()
          mainWindow.setContentView()
        })
    }
}

global.ka = [] // KEEP ALIVE
global.supportedHarwareModels = ['d101ap']
global.isDeviceConnected = false
global.SHSHFilePath = ''
global.deviceList = {
  'iPhone8,1': {
    name: 'iPhone 6s'
  },
  'iPhone8,2': {
    name: 'iPhone 6s Plus'
  },
  'iPhone8,4': {
    name: 'iPhone SE (1st Gen)'
  },
  'iPhone9,1': {
    name: 'iPhone 7'
  },
  'iPhone9,2': {
    name: 'iPhone 7 Plus'
  },
  'iPhone9,3': {
    name: 'iPhone 7'
  },
  'iPhone9,4': {
    name: 'iPhone 7 Plus'
  },
  'iPhone10,1': {
    name: 'iPhone 8'
  },
  'iPhone10,2': {
    name: 'iPhone 8 Plus'
  },
  'iPhone10,4': {
    name: 'iPhone 8'
  },
  'iPhone10,5': {
    name: 'iPhone 8 Plus'
  }
}
global.app = new Delegate()
app.ready()
