BottomTab = require './bottom-tab'
BottomStatus = require './bottom-status'

{CompositeDisposable, BufferedProcess, NotificationManager} = require 'atom'

module.exports =
    config:
        executablePath:
            type: 'string'
            default: ''
            description: 'Anubis compiler executable path'
        executableName:
            type: 'string'
            default: 'anubis'
            description: 'Anubis compiler executable name'
        compilationSource:
            type: 'string'
            default: ''
            description: 'A file which contain a "global"'
        compilerArguments:
            type: 'string'
            default: ''
            description: 'Compilation arguments'
        statusIconPosition:
            title: 'Position of Build Icon on Bottom Bar'
            description: 'Requires a reload/restart to update'
            enum: ['Left', 'Right']
            type: 'string'
            default: 'Left'

    subscriptions: null

    activate: ->
        @showPanel = true
        @showBubble = true
        @underlineIssues = true

        @messages = new Set
        @markers = []
        @statusTiles = []

        @tabs = new Map
        @tabs.set 'build', new BottomTab()

        @tabs.get('build').initialize 'build', => @changeTab('build')
        @tabs.get('build').visibility = true

        @panel = document.createElement 'div'
        @panel.id = 'language-anubis-panel'

        @bottomStatus = new BottomStatus()

        @bottomStatus.initialize()
        @bottomStatus.addEventListener 'click', ->
            atom.commands.dispatch atom.views.getView(atom.workspace), 'language-anubis:next-error'
        @panelWorkspace = atom.workspace.addBottomPanel item: @panel, visible: false

        @subscriptions = new CompositeDisposable
        @subscriptions.add atom.commands.add 'atom-workspace',
            'anubis:compile': (event) ->
            options =
                cwd: atom.project.getPaths()[0]
                env: process.env
            command = (atom.config.get 'language-anubis.executablePath') + (atom.config.get 'language-anubis.executableName')
            args = [atom.config.get 'language-anubis.compilationSource', "-nocolor"]
            args = args.concat (atom.config.get 'language-anubis.compilerArguments').split(" ")

            stdout = (output) -> console.log(output)
            stderr = (output) -> console.log(output)
            exit = (code) ->
                notification_options =
                    detail: "Could not compile the file '" + args[0] + "' because the Anubis compiler exited with #{code}."
                atom.notifications.addError "The anubis compiler exited with #{code}.", notification_options
            SpawnedProcess = new BufferedProcess({command, args, options, stdout, stderr})
            SpawnedProcess.onWillThrowError (err) =>
                return unless err?
                    if err.error.code is 'ENOENT'
                        notification_options =
                            detail: "Could not compile the file '" + args[0] + "' because the Anubis compiler was not found. (check your path/installation or specify the compiler location in the package settings)"
                        atom.notifications.addError "The anubis compiler was not found.", notification_options

    deactivate: ->
        @subscriptions.dispose()
        for statusTile in @statusTiles
            statusTile.destroy()

    consumeStatusBar: (statusBar) ->
        @statusTiles.push statusBar.addLeftTile
            item: @tabs.get('build'),
            priority: -1004
        statusIconPosition = atom.config.get('language-anubis.statusIconPosition')
        @statusTiles.push statusBar["add#{statusIconPosition}Tile"]
            item: @bottomStatus,
            priority: -1003

    updateBubble: (point) ->
        @removeBubble()
        return unless @showBubble
        return unless @messages.size
        activeEditor = atom.workspace.getActiveTextEditor()
        return unless activeEditor?.getPath()
        point = point || activeEditor.getCursorBufferPosition()
        try @messages.forEach (message) =>
            return unless message.currentFile
            return unless message.range?.containsPoint point
            @bubble = activeEditor.markBufferRange([point, point], {invalidate: 'never'})
            activeEditor.decorateMarker(
                @bubble
                {
                    type: 'overlay',
                    position: 'tail',
                    item: @renderBubble(message)
                }
            )
            throw null

    setPanelVisibility: (Status) ->
        if Status
            @panelWorkspace.show() unless @panelWorkspace.isVisible()
        else
            @panelWorkspace.hide() if @panelWorkspace.isVisible()

    renderPanel: ->
        @panel.innerHTML = ''
        @removeMarkers()
        @removeBubble()
        if not @messages.size
            return @setPanelVisibility(false)
        @setPanelVisibility(true)
        activeEditor = atom.workspace.getActiveTextEditor()
        @messages.forEach (message) =>
            if @scope is 'file' then return unless message.currentFile
            if message.currentFile and message.range #Add the decorations to the current TextEditor
                @markers.push marker = activeEditor.markBufferRange message.range, {invalidate: 'never'}
                activeEditor.decorateMarker(
                    marker, type: 'line-number', class: "language-anubis-highlight #{message.class}"
                )
            if @underlineIssues then activeEditor.decorateMarker(
                marker, type: 'highlight', class: "language-anubis-highlight #{message.class}"
            )

            if @scope is 'line'
                return if @lineMessages.indexOf(message) is -1

            Element = Message.fromMessage(message, addPath: @scope is 'project', cloneNode: true)

            @panel.appendChild Element
        @updateBubble()

    setShowPanel: (showPanel) ->
        atom.config.set('language-anubis.showErrorPanel', showPanel)
        @showPanel = showPanel
        if showPanel
            @panel.removeAttribute('hidden')
        else
            @panel.setAttribute('hidden', true)

    removeBubble: ->
        return unless @bubble
        @bubble.destroy()
        @bubble = null

    removeMarkers: ->
        return unless @markers.length
        for marker in @markers
            try marker.destroy()
        @markers = []

    changeTab: (Tab) ->
        if @getActiveTabKey() is Tab
            @showPanel = not @showPanel
            @tabs.forEach (tab, key) -> tab.active = false
        else
            @showPanel = true
            @scope = Tab
            @tabs.forEach (tab, key) -> tab.active = Tab is key
            @renderPanel()
        @setShowPanel @showPanel

    getActiveTabKey: ->
        activeKey = null
        @tabs.forEach (tab, key) -> activeKey = key if tab.active
        return activeKey

    getActiveTab: ->
        @tabs.entries().find (tab) -> tab.active
