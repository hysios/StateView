define ["jquery", "backbone", "lib/state-machine", "lib/state-view", 'exports'], ($, Backbone, StateMachine, StateView, exports) ->

	joinPath = (path, args...) ->
		paths = path.split '/'
		paths = paths.concat args
		paths.join '/'

	class MetaDataModel extends Backbone.Model

		constructor: (el, @options = {}) ->
			@el ||= el
			super(@options)
			@parse(@el)


		parse: (el) ->
			$(el).find("data").each (i, e) =>
				@set $(e).attr("meta"), $(e).text() || $(e).attr('value')

	class RESTfulRouter extends Backbone.Router

		constructor: (alias, @view, options) ->
			@routes ||= {}
			@routes[alias["new"]] = "newPage"
			@routes[":id/#{alias["edit"]}"] = "editPage"
			@routes[":id/#{alias["show"]}"] = "showPage"

			super(options)

		newPage: () ->
			@view.edit()

		editPage: (id) ->
			@view.edit()

		showPage: (id) ->
			@view.display()

	class ItemView extends StateView.AbstructStateView
		EVENT_NAMES = "blur focus focusin focusout load resize scroll unload click dblclick mousedown mouseup mousemove mouseover mouseout mouseenter mouseleave change select submit keydown keypress keyup error"

		# @routeAdapter = RESTfulRouter

		modelAdapter: MetaDataModel

		as: {
			new: 'new'
			create: 'create'
			show: 'show'
			edit: 'edit'
			update: 'update'
			destroy: 'destroy'
		}

		states:
			initial: 'none'

			events:  [
				{ name: 'display', 	from: ['none', 'create', 'update'], to: 'show' }
				{ name: 'editable', from: 'none', 						to: 'new' }
				{ name: 'editable', from: 'show', 						to: 'edit' }
				{ name: 'save', 	from: 'new', 						to: 'create' }
				{ name: 'save', 	from: 'edit', 						to: 'update' }
				{ name: 'back', 	from: 'edit', 						to: 'show' }
				{ name: 'back', 	from: 'new', 						to: 'none'}
				{ name: 'remove', 	from: ['show', 'edit'], 			to: 'destroy' }
			]

			callbacks: 
				onenterstate: (event, from, to, msg) ->
					console.log "event: #{event} from #{from} to #{to}"

	
		constructor: (@options) ->			
			@el = @options['el'] || @el
			super
			@model = @options['model'] || new @modelAdapter(@el)
			@eventBoundder()
			# ItemView.router ||= new ItemView.routeAdapter(@as, @)
		
		eventBoundder: () ->			
			@$("[state-transcation]").on EVENT_NAMES, (event) =>
				trigger_event = $(event.target).attr("state-event") || "click"
				if event.type == trigger_event
					transition = $(event.target).attr("state-transcation")
					@eventTrigger transition
					false

		eventTrigger: (name) ->
			@[name].apply(@)

		# enterNew: (event, from, to, msg) ->
		# 	@renderState('new')

		# afterCreate: (event, from, to, msg) ->
		# 	@fsm.transition()
		beforeDisplay: (event, from, to, msg) ->
			if from == 'update' || from == 'create'
				if msg?
					@renderHtml(msg)
			else
				@renderState(to)

		leaveShow: (event, from, to) ->
			if to == 'edit'
				@renderState('edit')

		beforeBack: (event, from , to ) ->
			@restoreState()

		enterEdit: (event, from, to, msg) ->
			@$("form").submit($.proxy(@submitForm, @))

		leaveEdit: (event, from, to, msg) ->
			if to == 'update'
				@$("form").append("<input name='_method' value='put' type='hidden' />")
				url = @getStateUrl 'update'
				
				$.post( url, @$("form").serialize(), 
					(data, state, xhr) =>			
						debugger		
						@transition()
						@display(data)				
				).error (data, state, xhr) => 
					debugger


				StateMachine.ASYNC

		submitForm: () ->
			url = if @current == 'edit'
				@$("form").append("<input name='_method' value='put' type='hidden' />")
				@getStateUrl 'update'
			else
				@getStateUrl 'create'

			
			@save()
			false

		render: () ->
			@renderState(@current)
			@eventBoundder()

		renderState: (state) ->
			url = @getStateUrl(state)
			@backupHtml = $(@el).html()
			$.ajax url, ajaxify: true, success: (data) =>
				$(@el).html(data)
				@eventBoundder()
				@transition()

			StateMachine.ASYNC

		renderHtml: (html) ->
			$(@el).html html
			@eventBoundder()

		restoreState: () ->
			$(@el).html(@backupHtml)
			@eventBoundder()

		getStateUrl: (state) ->
			state_path = @as[state]
			switch state
				when 'new'
					joinPath @urlRoot, state_path
				when 'create'
					@urlRoot
				when 'edit'
					joinPath @urlRoot, @model.get("id"), state_path
				when 'update', 'show', 'destroy'
					joinPath @urlRoot, @model.get("id")				

	class CollectionView extends StateView.AbstructStateView



	exports.ItemView = ItemView
	exports.CollectionView = CollectionView
	exports