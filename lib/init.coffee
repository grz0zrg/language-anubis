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
    compilerArguments:
      type: 'string'
      default: ''
      description: 'Compilation arguments'

  activate: ->
    console.log 'language-anubis activated'
    
