Reflux = require 'reflux'
{Actions} = require 'nylas-exports'
qs = require 'querystring'
_ = require 'underscore'

curlItemId = 0

DeveloperBarStore = Reflux.createStore
  init: ->
    @_setStoreDefaults()
    @_registerListeners()


  ########### PUBLIC #####################################################

  curlHistory: -> @_curlHistory

  longPollState: -> @_longPollState

  longPollHistory: -> @_longPollHistory

  visible: -> @_visible

  ########### PRIVATE ####################################################

  triggerThrottled: ->
    @_triggerThrottled ?= _.throttle(@trigger, 100)
    @_triggerThrottled()

  _setStoreDefaults: ->
    @_curlHistory = []
    @_longPollHistory = []
    @_longPollState = 'Unknown'
    @_visible = atom.inDevMode()

  _registerListeners: ->
    @listenTo Actions.didMakeAPIRequest, @_onAPIRequest
    @listenTo Actions.longPollReceivedRawDeltas, @_onLongPollDeltas
    @listenTo Actions.longPollStateChanged, @_onLongPollStateChange
    @listenTo Actions.clearDeveloperConsole, @_onClear
    @listenTo Actions.showDeveloperConsole, @_onShow

  _onShow: ->
    @_visible = true
    @trigger(@)

  _onClear: ->
    @_curlHistory = []
    @_longPollHistory = []
    @trigger(@)

  _onLongPollDeltas: (deltas) ->
    # Add a local timestamp to deltas so we can display it
    now = new Date()
    delta.timestamp = now for delta in deltas

    # Incoming deltas are [oldest...newest]. Append them to the beginning
    # of our internal history which is [newest...oldest]
    @_longPollHistory.unshift(deltas.reverse()...)
    if @_longPollHistory.length > 1000
      @_longPollHistory.splice(1000, @_longPollHistory.length - 1000)
    @triggerThrottled(@)

  _onLongPollStateChange: (state) ->
    @_longPollState = state
    @triggerThrottled(@)

  _onAPIRequest: ({request, response}) ->
    url = request.url
    if request.auth
      url = url.replace('://', "://#{request.auth.user}:#{request.auth.pass}@")
    if request.qs
      url += "?#{qs.stringify(request.qs)}"
    postBody = ""
    postBody = JSON.stringify(request.body).replace(/'/g, '\\u0027') if request.body
    data = ""
    data = "-d '#{postBody}'" unless request.method == 'GET'

    item =
      id: curlItemId
      command: "curl -X #{request.method} #{data} #{url}"
      statusCode: response?.statusCode || 0

    @_curlHistory.unshift(item)
    curlItemId += 1

    @triggerThrottled(@)

module.exports = DeveloperBarStore