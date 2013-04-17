define ["jquery", "backbone", "lib/state-machine", 'exports'], ($, Backbone, StateMachine, exports) ->


	_.mixin
		capitalize : (string) ->
			string.charAt(0).toUpperCase() + string.substring(1).toLowerCase()


	class AbstructStateView extends Backbone.View	

		constructor: (@options = {}) ->
			super
			@initial = @options['initial'] || @initial
			@error = @options['error'] || @stateError
			@fsm = StateMachine.create @gatherConfiguration()


		gatherConfiguration: () ->
			configure = @states
			configure['initial'] = @initial
			configure['target'] = @constructor.prototype

			callbacks = configure['callbacks'] || {}

			addToCallback = (name, func) ->
				callbacks[name] = func


			for event in configure.events
				# before, after

				@eventMethods event, addToCallback
				@stateMethods event, addToCallback			

			configure['callbacks'] = callbacks
			configure

		eventMethods: (event, handle) ->
			@cbMethods(event.name, ['before', 'after'], handle)

		stateMethods: (event, handle) ->
			for state in _([event.from, event.to]).flatten()
				@cbMethods(state, ['enter', 'leave'], handle)

		cbMethods: (name, set, handle) ->
			for prefix in set
				attribute = "on#{prefix}#{name}"
				func = "#{prefix}#{_(name).capitalize()}"
				if _.isFunction(@[func])
					handle.call @, attribute, @[func]

		stateError: (eventName, from, to, args, errorCode, errorMessage) ->
		    msg =  'event ' + eventName + ' was naughty :- ' + errorMessage;
		    console.log msg
		    msg

	class StateView extends AbstructStateView

	exports.AbstructStateView = AbstructStateView
	exports.StateView = StateView
	exports