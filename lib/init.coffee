{CompositeDisposable, BufferedProcess, NotificationManager} = require 'atom'
{MessagePanelView, LineMessageView, PlainMessageView} = require 'atom-message-panel'
{exec} = require 'child_process'
path = require 'path'

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
        projectName:
            type: 'string'
            default: ''
            description: 'The project path you want to enable compilation for'
        compilerArguments:
            type: 'string'
            default: ''
            description: 'Compilation arguments'
        compilationSource:
            type: 'string'
            default: ''
            description: 'A file which contain a "global"'
        compileOnSave:
            type: 'boolean'
            default: 'false'
            description: 'Enable/Disable compilation on save'
        buildPanelMaxHeight:
            type: 'number'
            default: '300'
            description: 'Max height of the build panel (px)'

    subscriptions: null
    compilerProcess: null
    compilerMessages: []

    activate: ->
        @messages = new MessagePanelView
            title: 'Anubis build panel. (F9 to compile an Anubis source file)'
            position: 'bottom'
            maxHeight: atom.config.get('language-anubis.buildPanelMaxHeight') + "px"
            rawTitle: true

        @messages.attach()
        @messages.toggle()
        @messages.hide()

        pname = atom.config.get('language-anubis.projectName')
        if atom.workspace.getActiveTextEditor()
            if pname != "" && atom.workspace.getActiveTextEditor().getPath().indexOf(pname) != -1
                @messages.show()
            else
                @messages.hide()

        atom.workspace.onDidChangeActivePaneItem (editor) =>
            pname = atom.config.get('language-anubis.projectName')

            if editor
                if editor.getPath
                    if pname != "" && editor.getPath().indexOf(pname) != -1
                        @messages.show()
                    else
                        @messages.hide()

        atom.workspace.observeTextEditors (editor) ->
            editor.onDidSave ->
                if atom.config.get('language-anubis.compileOnSave')
                    pname = atom.config.get('language-anubis.projectName')

                    if editor
                        if editor.getPath
                            if pname != "" && editor.getPath().indexOf(pname) != -1
                                atom.commands.dispatch(atom.views.getView(editor), 'anubis:compile')

        @disposable = atom.commands.add 'atom-text-editor', 'anubis:compile': (event) =>
            @messages.clear()

            if @compilerProcess
                @compilerProcess.kill()
                @compilerProcess = null

            options =
                cwd: atom.project.getPaths()[0]
                env: process.env
            command = (atom.config.get 'language-anubis.executablePath') + (atom.config.get 'language-anubis.executableName')
            args = [atom.config.get('language-anubis.compilationSource'), "-nocolor"]
            args = args.concat (atom.config.get 'language-anubis.compilerArguments').split(" ")

            @messages.setTitle('<span style="font-weight: bold; color: white;">Compiling ' + args[0] + ' ...</span>', true)

            parent = @

            stdout = (output) =>
                @messages.add new PlainMessageView
                    message: output
                parent.compilerMessages.push(output)
            stderr = (output) =>
                @messages.add new PlainMessageView
                    message: output
                parent.compilerMessages.push(output)
            exit = (code) ->
                parent.parseCompilerOutput()
            @compilerProcess = new BufferedProcess({command, args, options, stdout, stderr, exit})
            @compilerProcess.onWillThrowError (err) =>
                return unless err?
                    if err.error.code is 'ENOENT'
                        notification_options =
                            detail: "Could not compile the file '" + args[0] + "' because the Anubis compiler was not found. (check your path/installation or specify the compiler location in the package settings)"
                        atom.notifications.addError "The anubis compiler was not found.", notification_options
                        @messages.setTitle("Could not compile the file '" + args[0] + "' because the Anubis compiler was not found.")

    deactivate: ->
        @messages.close()
        @disposable.dispose()

    parseCompilerOutput: ->
        @messages.clear()

        @compilerMessages = @compilerMessages.join "\n"

        compilerMessageRegex = /([a-zA-Z\/\\:_.]+) \(line (\d+), column (\d+)\) (\w+ (E|W)(\d+):([\s\S]+?)(?=[a-zA-Z\/\\:_.#]+ (?:\(line \d+, column \d+\)|module|# #|time)|$))/g

        warnings = 0
        errors = 0

        while((messages_arr = compilerMessageRegex.exec(@compilerMessages)) != null)
            msg_type = messages_arr[5]
            color = ""
            if msg_type == "W"
                warnings += 1
                color = "yellow"
            else if msg_type == "E"
                errors += 1
                color = "red"

            message = messages_arr[7]

            message = message.replace(/(?:\r\n|\r|\n)/g, '<br />')

            @messages.add new LineMessageView
                file: messages_arr[1]
                line: messages_arr[2]
                character: messages_arr[3]
                preview: message
                color: color

        title = "<span style='font-weight: bold;'>Build failed.</span>"

        if warnings > 0 || errors > 0
            title += "&nbsp;"
            @messages.toggle()

        if errors > 0
            title += "<span style='color: red;'>" + errors + " <span font-weight: bold;'>Error</span> </span>"
        else
            buildTimeRegex = /^Build time: (.* seconds)$/gm
            buildTimes = @compilerMessages.match buildTimeRegex
            if buildTimes
                title = "<span style='color: green; font-weight: bold;'>" + buildTimes[buildTimes.length - 1] + "."
            else
                title = "<span style='color: green; font-weight: bold;'>Build successful."
            title += "</span>"
            @compilerMessages = @compilerMessages.replace(/(?:\r\n|\r|\n)/g, '<br />')
            @messages.add new PlainMessageView
                message: @compilerMessages
                raw: true

        if warnings > 0
            title += "<span style='color: yellow;'>" + warnings + " <span font-weight: bold;'>Warning</span> </span>"

        @messages.setTitle(title, true)

        @compilerMessages = []
